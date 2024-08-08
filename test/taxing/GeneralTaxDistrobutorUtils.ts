
export function packWeights(ws: number[]): bigint {
	let n = 0n;
	ws.forEach(w => {
		n = (n << 8n) + BigInt(w); // Shift left by 8 bits and add the current weight
	});
	console.log(`Packed ${ws} into ${n.toString(16)}`);
	return n;
}
