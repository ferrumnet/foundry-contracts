import { ethers } from "hardhat";
import { abi, deployUsingDeployer, getCtx, getTransactionLog, Salt, TestContext, Wei, ZeroAddress } from "../common/Utils";
import { 
	GenericUpgradableTokenMintable,
	GenericUpgradableTokenMintable__factory,
	TransparentUpgradeableProxy__factory,
	DirectMinimalErc20__factory,
	DirectMinimalErc20
} from '../../typechain-types';


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
	const logic = await (await logicF.deploy()).getAddress();
	const logic2F = await ethers.getContractFactory('GenericUpgradableTokenMintable') as unknown as GenericUpgradableTokenMintable__factory;
	const logic2 =  await logic2F.deploy() as GenericUpgradableTokenMintable;
	const logic2Address = await logic2.getAddress();
	const directTokF = await ethers.getContractFactory('DirectMinimalErc20') as unknown as DirectMinimalErc20__factory;
	const directToken = (await directTokF.deploy()) as DirectMinimalErc20;
	return {...ctx, logic, logic2: logic2Address, gut: logic2, directToken};
}

describe('Test a basic upgradabled tok, then upgrad the tok', function (){
	it('Can deploy a token, then upgrade it', async function() {
		const ctx = await deployLogics();
		const proxyF = await ethers.getContractFactory('TransparentUpgradeableProxy'
			) as unknown as TransparentUpgradeableProxy__factory;
		const data = ctx.gut.interface
			.encodeFunctionData('init', ['Yo Token', 'YO', Wei.from('100'), ctx.owner, ctx.owner]);
		const proxy = await proxyF.deploy(ctx.logic, ctx.owner, data);
		const tokdirF = await ethers.getContractFactory('GenericUpgradableTokenMintable');
		// const tokdir = await tokdirF.attach(await proxy.getAddress()).connect(ctx.wallets[1]);
		// console.log('Deployed token', tokdir.address, data);
		// console.log(`Token is ${await tokdir.name()} - ${await tokdir.symbol()} - ${await tokdir.totalSupply()}`);
		// console.log(`Owner is ${await tokdir.owner()} - ${ctx.owner}`);
	});
});