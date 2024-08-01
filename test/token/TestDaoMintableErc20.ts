import { abi, deployWithOwner, getCtx, TestContext, throws, Wei, ZeroAddress } from "../common/Utils";
import { DaoMintableErc20 } from '../../typechain-types';
import { TokenDao } from '../../typechain-types';
import { randomBytes } from "crypto";
import { getBridgeMethodCall } from "../common/Eip712Utils";
import { expect } from "chai";

const GOV_GROUP_ID = 88;
const _it: any = () => {};

function id() {
    return '0x' + randomBytes(32).toString('hex');
}

function expiry() {
    return Math.round(Date.now() / 1000) + 10000;
}

interface DaoTokenContext extends TestContext {
    daoToken: DaoMintableErc20;
    dao: TokenDao;
}

async function context() {
	const ctx = await getCtx();
    console.log('Starting');
    const data = abi.encode(['string', 'string'], ['Test Dao Mintable', 'TDM']);
    console.log('Starting ctx', data);
    const daoToken = await deployWithOwner(ctx, 'DaoMintableErc20', ctx.owner, data) as unknown as DaoMintableErc20;
    console.log('DAO Token mited ', await daoToken.getAddress());
    const dao = await deployWithOwner(ctx, 'contracts/contracts/signature/TokenDao.sol:TokenDao', ctx.owner, '0x') as unknown as TokenDao;
    console.log('Minted token DAO', await dao.getAddress());
    await dao.setToken(daoToken);
    return {
        ...ctx,
        dao, daoToken,
    };
}

async function crucibleMethodCall(
		ctx: DaoTokenContext,
		methodName: string,
		args: {type: string, name: string, value: string}[], sks: string[]) {
	const name = (await ctx.dao.NAME()).toString();
	const version = (await ctx.dao.VERSION()).toString();
	return getBridgeMethodCall(
		name, version, ctx.chainId, await ctx.dao.getAddress(), methodName, args, sks);
}

async function init(ctx: DaoTokenContext) {
    const quorum = id().substring(0, 42);
    console.log('Initializing the ownership to three signatures...', {quorum, GOV_GROUP_ID});
    await ctx.dao.initializeQuorum(quorum, GOV_GROUP_ID, 2, 0, [
        ctx.wallets[3],
        ctx.wallets[4],
        ctx.wallets[5],
    ],);
    console.log('Initialized ', await ctx.dao.quorumList(0));
    console.log('Quorum subsciption is ', await ctx.dao.quorumSubscriptions(ctx.wallets[3]), 'vs', quorum);
}

describe('TestTokenDaoMintable', function (){
	_it('Can deploy a token, then upgrade it', async function() {
        const ctx = await context();
        const {dao} = ctx;
        console.log('Transfer ownership to dap');
        await ctx.daoToken.transferOwnership(ctx.dao);
        console.log('Owner is ', await ctx.daoToken.owner());
        await init(ctx);

        const exp = expiry().toString();
        const salt = id();
        console.log('Try signing with 1 sig');
        let call = await crucibleMethodCall(ctx,
            'Mint', [
                { type: 'uint256', name: 'amount', value: Wei.from('100') },
                { type: 'address', name: 'to', value: ctx.acc1 },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[3]]);
        await throws(dao.mint(Wei.from('100'), ctx.acc1, salt, exp, call.signature!), 'MSC: not enough signatures');
        console.log('Obviously should not')

        console.log('Try signing with 2 sig. But one of them are wrong');
        call = await crucibleMethodCall(ctx,
            'Mint', [
                { type: 'uint256', name: 'amount', value: Wei.from('100') },
                { type: 'address', name: 'to', value: ctx.acc1 },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[0], ctx.sks[5]]);
        await throws(dao.mint(Wei.from('100'), ctx.acc1, salt, exp, call.signature!), 'MSPS: Invalid signature');
        console.log('Obviously should not');

        console.log(`Token address is ${await dao.token()}`)
        console.log('Now sign with 2 valid sigs.');
        call = await crucibleMethodCall(ctx,
            'Mint', [
                { type: 'uint256', name: 'amount', value: Wei.from('100') },
                { type: 'address', name: 'to', value: ctx.acc1 },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[3], ctx.sks[4]]);
        await dao.mint(Wei.from('100'), ctx.acc1, salt, exp, call.signature!);
        let totalSupply = Wei.to((await ctx.daoToken.totalSupply()).toString());
        console.log('The total supply of the token is ', totalSupply);
        expect(totalSupply).to.be.eq('100.0');
    });
    _it('Can transfer ownership out using multisig', async function() {
        const ctx = await context();
        await ctx.daoToken.transferOwnership(ctx.dao);
        await init(ctx);

        const exp = expiry().toString();
        const salt = id();
        let owner = (await ctx.daoToken.owner()).toString();
        expect(owner.toLocaleLowerCase()).is.not.eq(ctx.owner.toLocaleLowerCase());
        console.log('Owner is currently ', owner)
        const call = await crucibleMethodCall(ctx,
            'UpgradeDao', [
                { type: 'address', name: 'newDao', value: ctx.owner },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[3], ctx.sks[4]]);
        console.log('Change the token ownership to someone else');
        await ctx.dao.upgradeDao(
            ctx.owner, salt, exp, call.signature!);
        owner = (await ctx.daoToken.owner()).toString();
        console.log('New owner is currently ', owner)
        expect(owner.toLocaleLowerCase()).is.eq(ctx.owner.toLocaleLowerCase());
    });
    _it('Can transfer ownership as owner', async function() {
        const ctx = await context();
        await ctx.daoToken.transferOwnership(ctx.dao);
        await init(ctx);

        let owner = (await ctx.daoToken.owner()).toString();
        expect(owner.toLocaleLowerCase()).is.not.eq(ctx.owner.toLocaleLowerCase());
        console.log('Owner is currently ', owner);
        await ctx.dao.changeTokenOwner(ctx.owner);
        
        owner = (await ctx.daoToken.owner()).toString();
        console.log('New owner is currently ', owner)
        expect(owner.toLocaleLowerCase()).is.eq(ctx.owner.toLocaleLowerCase());
    });
    _it('Can add and remove signers', async function() {
        const ctx = await context();
        await ctx.daoToken.transferOwnership(ctx.dao);
        await init(ctx);
        const quorum = (await ctx.dao.quorumList(0)).toString().toLocaleLowerCase();
        let sub = await ctx.dao.quorumSubscriptions(ctx.acc1);
        expect(sub.id).to.be.eq(ZeroAddress);

        const exp = expiry().toString();
        let salt = id();
        let call = await crucibleMethodCall(ctx,
            'AddToQuorum', [
                { type: 'address', name: '_address', value: ctx.acc1 },
                { type: 'address', name: 'quorumId', value: quorum },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[3], ctx.sks[4]]);
        await ctx.dao.addToQuorum(ctx.acc1, quorum, salt, exp, call.signature!);
        
        console.log('Make sure we are subscribed properly');
        sub = await ctx.dao.quorumSubscriptions(ctx.acc1);
        expect(sub.id.toLocaleLowerCase()).to.be.eq(quorum.toLocaleLowerCase());

        const subz = (await ctx.dao.quorumsSubscribers(quorum)).toString();
        console.log(`We have ${subz} subscribers`);
        expect(subz).to.be.eq('4');

        console.log('Update the min signature');

        salt = id();
        call = await crucibleMethodCall(ctx,
            'UpdateMinSignature', [
                { type: 'address', name: 'quorumId', value: quorum },
                { type: 'uint16', name: 'minSignature', value: '4' },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[3], ctx.sks[4]]);
        await ctx.dao.updateMinSignature(quorum, '4', salt, exp, call.signature!);
        const upq = await ctx.dao.quorums(quorum);
        console.log('Updated quorum is ', upq);
        expect(upq.minSignatures).to.be.eq(4);
    });
    it('Can add and remove signers', async function() {
        const ctx = await context();
        await ctx.daoToken.transferOwnership(ctx.dao);
        await init(ctx);

        const exp = expiry().toString();
        let salt = id();
        console.log('Remove an address [that does not exist] from quorum');
        let call = await crucibleMethodCall(ctx,
            'RemoveFromQuorum', [
                { type: 'address', name: '_address', value: ctx.acc1 },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[3], ctx.sks[4]]);
        await throws(ctx.dao.removeFromQuorum(ctx.acc1, salt, exp, call.signature!), 'MSC: subscription not found');

        salt = id();
        call = await crucibleMethodCall(ctx,
            'RemoveFromQuorum', [
                { type: 'address', name: '_address', value: ctx.wallets[3] },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[3], ctx.sks[4]]);
        await ctx.dao.removeFromQuorum(ctx.wallets[3], salt, exp, call.signature!);
        console.log('Address removed');
        let sub = await ctx.dao.quorumSubscriptions(ctx.acc3);
        expect(sub.id).to.be.eq(ZeroAddress);

        console.log('Now removing one more address. This will not work as we will go below minSig');
        salt = id();
        call = await crucibleMethodCall(ctx,
            'RemoveFromQuorum', [
                { type: 'address', name: '_address', value: ctx.wallets[4] },
                { type: 'bytes32', name: 'salt', value: salt },
                { type: 'uint64',  name: 'expiry', value: exp },
            ],
            [ctx.sks[4], ctx.sks[5]]);
        await throws(ctx.dao.removeFromQuorum(ctx.wallets[4], salt, exp, call.signature!), 'MSC: quorum becomes ususable');
    });
});