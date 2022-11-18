import { ethers } from "hardhat";
import { abi, deployUsingDeployer, getCtx, getTransactionLog, Salt, TestContext, Wei, ZeroAddress } from "../common/Utils";
import { GenericUpgradableTokenMintable } from '../../typechain/GenericUpgradableTokenMintable';
import { GenericUpgradableTokenMintable__factory } from
	"../../typechain/factories/GenericUpgradableTokenMintable__factory";
import { TransparentUpgradeableProxy__factory } from '../../typechain/factories/TransparentUpgradeableProxy__factory';
import { DirectMinimalErc20__factory } from '../../typechain/factories/DirectMinimalErc20__factory';
import { DirectMinimalErc20 } from '../../typechain/DirectMinimalErc20';

const f = GenericUpgradableTokenMintable__factory;

interface TokTestContext extends TestContext {
	logic: string;
	logic2: string;
	directToken: DirectMinimalErc20;
	gut: GenericUpgradableTokenMintable;
}

async function deployLogics(): Promise<TokTestContext> {
	const ctx = await getCtx();
	const logicF = await ethers.getContractFactory('GenericUpgradableToken');
	const logic = (await logicF.deploy()).address;
	const logic2F = await ethers.getContractFactory('GenericUpgradableTokenMintable') as GenericUpgradableTokenMintable__factory;
	const logic2 = await logic2F.deploy() as GenericUpgradableTokenMintable;
	const directTokF = await ethers.getContractFactory('DirectMinimalErc20') as DirectMinimalErc20__factory;
	const directToken = (await directTokF.deploy()) as DirectMinimalErc20;
	return {...ctx, logic, logic2: logic2.address, gut: logic2, directToken};
}

describe('Test a basic upgradabled tok, then upgrad the tok', function (){
	it('Can deploy a token, then upgrade it', async function() {
		const ctx = await deployLogics();
		const proxyF = await ethers.getContractFactory('TransparentUpgradeableProxy'
			) as TransparentUpgradeableProxy__factory;
		const data = ctx.gut.interface
			.encodeFunctionData('init', ['Yo Token', 'YO', Wei.from('100'), ctx.owner, ctx.owner]);
		const proxy = await proxyF.deploy(ctx.logic, ctx.owner, data);
		const tokdirF = await ethers.getContractFactory('GenericUpgradableTokenMintable');
		const tokdir = await tokdirF.attach(proxy.address).connect(ctx.wallets[1]);
		console.log('Deployed token', tokdir.address, data);
		console.log(`Token is ${await tokdir.name()} - ${await tokdir.symbol()} - ${await tokdir.totalSupply()}`);
		console.log(`Owner is ${await tokdir.owner()} - ${ctx.owner}`);
	});
});