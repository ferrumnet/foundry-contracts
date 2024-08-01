import { expect } from "chai";
import { ethers } from "hardhat";
import { abi, deploy, deployDummyToken, deployWithOwner, getCtx, getGasLimit, throws, validateBalances, Wei, ZeroAddress } from "../common/Utils";
import { GeneralTaxDistributor } from '../../typechain-types';
import { BigNumberish } from "ethers";
import { packWeights } from "./GeneralTaxDistrobutorUtils";

/*
Scanario:
- deploy a few tokens
- set a bunch as tax target with different ratio
- distribute a bunch and check results

proper test?
- run thousands, and average.
*/

describe('GeneralTaxDistributor', function (){
	it('Can distribute tax', async function() {
		const ctx = await getCtx();
		await deployDummyToken(ctx);
		// 0 threshol means always random returns true.
		const ranThresholdX1000 = 500;
		const gtd = await deployWithOwner(
			ctx, 'contracts/contracts/taxing/GeneralTaxDistributor.sol:GeneralTaxDistributor', ctx.owner, abi.encode(['uint256'], [ranThresholdX1000])) as unknown as GeneralTaxDistributor;
		await ctx.token!.transfer(gtd, Wei.from('2'));
		console.log('GTD balance is', await Wei.bal(ctx.token, await gtd.getAddress()));

		console.log(`About to dist tax. It should fail because targetInfos have no been set, so tries to access out-of-bounds element in targetInfos array.`);
		await throws(gtd.distributeTaxDirect(ctx.token), 'GTD: invalid idx');

		// Now do a global config and thigs should be fine
		const infos: { tgt: string; tType: BigNumberish }[] = [];
		infos.push({tgt: ctx.acc2, tType: 2 });
		infos.push({tgt: ctx.acc1, tType: 2 });
		infos.push({tgt: ZeroAddress, tType: 1 }); //burn
		const weights = [40, 40, 20];
		await gtd.setGlobalTargetInfos(infos, packWeights(weights));
		console.log('Weights were set!');
		console.log('globalTargetConfig: ', await gtd.globalTargetConfig());
		console.log('targetInfos: ',
			await gtd.targetInfos(0),
			await gtd.targetInfos(1),
			await gtd.targetInfos(2));

		console.log('Now lets distribute the tax');
		await gtd.distributeTaxDirect(ctx.token);
		console.log('Post tax dist: ', await Wei.bal(ctx.token, ctx.acc2));

		await validateBalances(ctx.token, [[ctx.owner, '0'], [ctx.acc1, '0'], [ctx.acc2, '0'] ], 'PRE');
		let totalSup = Wei.to(await ctx.token!.totalSupply());
		console.log(`PRE - Total Supply is ${totalSup}`);
		// Run in a loop
		for (let i=0; i<20; i++) {
			await ctx.token!.transfer(gtd, Wei.from('2'));
			await gtd.distributeTaxDirect(ctx.token);
			totalSup = Wei.to(await ctx.token!.totalSupply());
			console.log(`POST - Total Supply is ${totalSup}`);
			await validateBalances(ctx.token, [[ctx.owner, '0'], [ctx.acc1, '0'], [ctx.acc2, '0'] ], 'POST');
			console.log('---------------------------------------------------------------');
		}

		console.log('Now continue with the randomized dist event')
		// Run in a loop
		let randomCaller = ctx.owner;
		for (let i=0; i<20; i++) {
			await ctx.token!.transfer(gtd, Wei.from('2'));
			if (i > 2 && i < 40) {
				randomCaller = randomCaller.substr(0, i) + (i%16).toString(16) + randomCaller.substr(i+1);
			}
			console.log('RANDOM CALLER', randomCaller)
			const tx = await gtd.distributeTax(await ctx.token.getAddress());
			console.log('Gas used: ', await getGasLimit(tx));
			totalSup = Wei.to(await ctx.token!.totalSupply());
			console.log(`POST - Total Supply is ${totalSup}`);
			await validateBalances(ctx.token, [[ctx.owner, '0'], [ctx.acc1, '0'], [ctx.acc2, '0'] ], 'POST');
			console.log('---------------------------------------------------------------');
		}
	});
})
