import { ethers } from 'hardhat';
import { 
    IUniswapV2Router02,
    IUniswapV2Factory,
    ERC20 as IERC20
} from '../../typechain-types'
import { expiryInFuture, Wei } from './Utils';

export class ERC20 {
    private _token: IERC20|undefined;
    constructor(public address: string) {}

    async amountToMachine(humanAmount: string) {
        const deci = await (await this.token()).decimals();

        return (BigInt(humanAmount) * BigInt(10) ** BigInt(deci)).toString();
    }

    async amountToHuman(machineAmount: string) {
        const deci = await (await this.token()).decimals();
        return (BigInt(machineAmount) / BigInt(10) ** BigInt(deci)).toString();
    }

    async token() {
        if (!this._token) {
            this._token = await ethers.getContractAt('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20', this.address) as unknown as  IERC20;
        }
        return this._token!;
    }

    async balance(addr: string) {
        const bal = (await (await this.token()).balanceOf(addr)).toString();
        return await this.amountToHuman(bal);
    }
}

export class Pair {
    base: ERC20;
    token: ERC20;
    pair: ERC20|undefined;
    constructor(private baseAddr: string, private tokenAddr: string) {
        this.base = new ERC20(baseAddr);
        this.token = new ERC20(tokenAddr);
    }
    async init(fac: IUniswapV2Factory) {
        const pairAddr = await fac.getPair(this.baseAddr, this.tokenAddr);
        this.pair = new ERC20(pairAddr);
    }
}

export class UniswapV2 {
    public static readonly ETH_ROUTER = '0x7a250d5630b4cf539739df2c5dacb4c659f2488d';
    public router: IUniswapV2Router02|undefined;
    public factory: IUniswapV2Factory|undefined;
    public baseToken: ERC20|undefined;
    public tradeToken: ERC20|undefined;
    constructor(
        private routerAddress: string,
    ) {
    }

    async init() {
        this.router = await ethers.getContractAt('IUniswapV2Router02', this.routerAddress) as unknown as IUniswapV2Router02;
        const factoryAddress = await this.router.factory();
        this.factory = await ethers.getContractAt('IUniswapV2Factory', factoryAddress) as unknown as IUniswapV2Factory;
    }

    async addLiquidity(tok1: string, tok2: string, amount1: string, amount2: string, to: string) {
        const p = new Pair(tok1, tok2);
        const amount1M = await p.base.amountToMachine(amount1);
        const amount2M = await p.token.amountToMachine(amount2);
        const deadline = expiryInFuture();
        await this.router?.addLiquidity(tok1, tok2, amount1M, amount2M, '0', '0', to, deadline);
    }

    async addLiquidityETH(tok1: string, amount1: string, amountEth: string, to: string) {
        const amount1M = await new ERC20(tok1).amountToMachine(amount1);
        const amount2M = Wei.from(amountEth);
        const deadline = expiryInFuture();
        await this.router!.addLiquidityETH(tok1, amount1M, '0', '0', to, deadline, { value: amount2M });
    }

    async swapTokenForTokens(path: string[], amountIn: string, to: string) {
        const amountInM = await new ERC20(path[0]).amountToMachine(amountIn);
        const deadline = expiryInFuture();
        await this.router!.swapExactTokensForTokens(amountInM, '0', path, to, deadline);
    }

    async swapTokensForEth(path: string[], amountIn: string, to: string) {
        path.push(await this.router?.WETH()!);
        const amountInM = await new ERC20(path[0]).amountToMachine(amountIn);
        const deadline = expiryInFuture();
        await this.router!.swapExactTokensForETH(amountInM, '0', path, to, deadline);
    }

    async swapEthForTokens(path: string[], amountIn: string, to: string) {
        path = [await this.router!.WETH()].concat(path);
        const amountInM = Wei.from(amountIn);
        const deadline = expiryInFuture();
        await this.router!.swapExactETHForTokens('0', path, to, deadline, { value: amountInM });
    }
}