import { ethers } from "hardhat";
import { ERC20, UniswapV2 } from "./UniswapV2";
import { getCtx, Wei } from "./Utils";
import hre from 'hardhat';

const USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7';

/**
 * Note. run this against the main ethereum network.
 * Run the node as follows:
 * npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/<key>
 */
describe("Get Prices", function () {
    it('the Test', async function () {
        const res = await hre.network.provider.send("hardhat_metadata", []);
        if (!res.forkedNetwork || res.forkedNetwork.chainId != 1) {
            console.log('Not forking mainnet');
            return;
        }

        const ctx = await getCtx();
        const uniV2 = new UniswapV2(UniswapV2.ETH_ROUTER);
        await uniV2.init();
        const ethBal = await ethers.provider.getBalance(ctx.owner);
        const preBal = await new ERC20(USDT).balance(ctx.owner);
        console.log(`Current balance - ETH: ${Wei.to(ethBal.toString())}, USDT: ${preBal}`);
        await uniV2.swapEthForTokens([USDT], '1', ctx.owner);
        const postBal = await new ERC20(USDT).balance(ctx.owner);
        console.log(`Balance: ${preBal} vs ${postBal}`);
    });
});
