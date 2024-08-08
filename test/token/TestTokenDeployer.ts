import { ethers } from "hardhat";
import { deployUsingDeployer, getCtx, getTransactionLog, Salt, Wei, ZeroAddress } from "../common/Utils";
import { 
	FerrumProxyTokenDeployer,
	GenericUpgradableTokenMintable,
	TransparentUpgradeableProxy
} from '../../typechain-types';


/*
Scanario:
- deploy a few tokens
- set a bunch as tax target with different ratio
- distribute a bunch and check results

proper test?
- run thousands, and average.
*/

describe('TestTokenDeployer', function (){
	it('Can deploy a token, then upgrade it', async function() {
		const ctx = await getCtx();

		console.log('Deploying logic tokens');
		const gut = await deployUsingDeployer(
			'GenericUpgradableToken', ZeroAddress, '0x',
			await ctx.deployer.getAddress(), Salt);
		console.log("GenericUpgradableToken:", gut.address);

		const gutm = await deployUsingDeployer(
			'GenericUpgradableTokenMintable', ZeroAddress, '0x',
			await ctx.deployer.getAddress(), Salt);
		console.log("GenericUpgradableTokenMintable:", gutm.address);

		console.log('Deploying the deployer');
		const depFac = await ethers.getContractFactory('FerrumProxyTokenDeployer');
		const dep = await depFac.deploy() as unknown as FerrumProxyTokenDeployer;
		const deped = await dep.deployToken(gut, 'Test tokoon', 'TTN', '200000000000000000000', '0x880E0f3c6641C7fd4804136781F9632C0738038f');

		if (1===1) { return; }
		// const deped = await dep.deployToken(gut.address, 'Test tokoon', 'TTN', Wei.from('10'), ctx.owner);
		const log = await getTransactionLog(deped.hash, dep, 'TokenDeployed');
		console.log('TOKEN Deploted to ', log.token)
		const tFac = await ethers.getContractFactory('GenericUpgradableTokenMintable');
		const tok = await tFac.attach(log.token) as unknown as GenericUpgradableTokenMintable;

		console.log(`Token owner is `, await tok.connect(ctx.signers.acc1).owner());
		console.log(`Token total supply is ${Wei.to((await tok.connect(ctx.signers.acc1).totalSupply()).toString())}`);

		const data = await dep.updateTotalSupplyMethodData(ctx.owner, Wei.from('20'));
		console.log('Now upgrading....', data);

		const upgFac = await ethers.getContractFactory('TransparentUpgradeableProxy');
		const upg = upgFac.attach(log.token) as unknown as TransparentUpgradeableProxy;
		console.log('Just upgrade')
		// await upg.upgradeTo(gutm.address);
		console.log('Just upgrade and call')
		// await upg.upgradeToAndCall(gutm.address, data);

		console.log(`Token total supply is ${Wei.to(
			(await tok.connect(ctx.signers.acc1).totalSupply()).toString())}`)
	});
});