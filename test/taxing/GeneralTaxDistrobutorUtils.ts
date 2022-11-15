import { BigNumber, BigNumberish } from "ethers";

export function packWeights(ws: number[]) {
	let n = BigNumber.from(0);
	ws.forEach(w => {
		n = n.shl(8).add(w);
	});
	console.log(`Packed ${ws} into ${n.toHexString()}`);
	return n;
}