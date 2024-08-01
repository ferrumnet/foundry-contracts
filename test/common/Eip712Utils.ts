import Web3 from 'web3';
import {ethers} from 'hardhat'
import {ecsign, toRpcSig, fromRpcSig, ecrecover, pubToAddress} from 'ethereumjs-util';

type HexString  = string;

export interface Eip712Params {
    contractName: string;
    contractVersion: string;
    method: string;
    args: { type: string, name: string, value: string }[],
    hash?: HexString;
    signature?: HexString;
}

export function domainSeparator(
	contractName: string,
	contractVersion: string,
	netId: number,
	contractAddress: HexString
) {
    const hashedName = Web3.utils.keccak256(Web3.utils.utf8ToHex(contractName));
    const hashedVersion = Web3.utils.keccak256(Web3.utils.utf8ToHex(contractVersion));
    const typeHash = Web3.utils.keccak256(
        Web3.utils.utf8ToHex("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));
	const abiCoder = new ethers.AbiCoder();
    return Web3.utils.keccak256(
        abiCoder.encode(
            ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
            [typeHash, hashedName, hashedVersion, netId, contractAddress]
        )
    );
}

export function fixSig(sig: HexString) {
    const rs = sig.substring(0, sig.length - 2);
    let v = sig.substring(sig.length - 2);
    if (v === '00' || v ==='37' || v === '25') {
        v = '1b'
        } else if (v === '01' || v === '38' || v === '26') {
        v = '1c'
    }
    return rs+v;
}

export function produceSignature(
        netId: number,
        contractAddress: HexString,
        eipParams: Eip712Params): Eip712Params {
    const methodSig = `${eipParams.method}(${eipParams.args.map(p => `${p.type} ${p.name}`).join(',')})`
    const methodHash = Web3.utils.keccak256(Web3.utils.utf8ToHex(methodSig));
    // const methodHash = Web3.utils.keccak256(
    //     Web3.utils.utf8ToHex('WithdrawSigned(address token, address payee,uint256 amount,bytes32 salt)'));

    // ['bytes32', 'address', 'address', 'uint256', 'bytes32'];
    const params = ['bytes32'].concat(eipParams.args.map(p => p.type));
	// console.log('methodSig: ', methodSig, params);
	const abiCoder = new ethers.AbiCoder();
    const structure = abiCoder.encode(params, [methodHash, ...eipParams.args.map(p => p.value)]);
    const structureHash = Web3.utils.keccak256(structure);
    const ds = domainSeparator(eipParams.contractName, eipParams.contractVersion, netId, contractAddress);
	// console.log('Method hash is ', methodHash, methodSig);
	// console.log('Structure hash is ', structureHash, {params});
    // console.log('values area', [methodHash, ...eipParams.args.map(p => p.value)]);
	// console.log('Domain separator is ', ds);
    // console.log('Chain ID is', netId);
    const hash = Web3.utils.soliditySha3("\x19\x01", ds, structureHash) as HexString;
    return {...eipParams, hash, signature: ''};
}

export function randomSalt() {
    return Web3.utils.randomHex(32);
}

export async function signWithPrivateKey(
	privateKey: HexString,
	hash: HexString,
) {
	const hashBuf = Buffer.from(hash!.replace('0x',''), 'hex');
	const sigP2 = ecsign(
		hashBuf,
		Buffer.from(privateKey.replace('0x',''), 'hex'),);
	const sig = fixSig(toRpcSig(sigP2.v, sigP2.r, sigP2.s));
	const recovered = ecrecover(hashBuf, sigP2.v, sigP2.r, sigP2.s);
	const addr = pubToAddress(recovered).toString('hex');
	console.log('     Signed with address', addr)
	return {sig, addr};
}

interface RSV {
	r: string; s: string; v: string;
}

export function multiSigToBytes(sigs: string[]): string {
	let sig: string = '';
	let vs: string = '';
	for (let i = 0; i<sigs.length; i++) {
		const rsv = fromRpcSig(sigs[i]);
		sig = sig + `${rsv.r.toString('hex')}${rsv.s.toString('hex')}`;
		vs = vs + rsv.v.toString(16);
	}
	const padding = (vs.length % 64) === 0 ? 0 : 64 - (vs.length % 64);
	vs = vs + '0'.repeat(padding);
	sig = sig + vs;
	return '0x' + sig;
}

export async function getBridgeMethodCall(
		contractName: string,
		contractVersion: string,
		chainId: number,
		bridge: string,
		methodName: string,
		args: {type: string, name: string, value: string}[], sks: string[]) {
	const web3 = new Web3();
	// console.log('We are going to bridge method call it ', args)
	const msg = produceSignature(
		chainId, bridge, {
			contractName: contractName,
			contractVersion: contractVersion,
			method: methodName,
			args,
		} as Eip712Params,
	);
	// console.log('About to producing msg ', msg)
	const sigs = [];
	for (const sk of sks) {
		console.log(`    About to sign with private key ${sk}`);
		const {sig, addr} = await signWithPrivateKey(sk, msg.hash!);
		sigs.push({sig, addr});
	}
    // Make sure that signatures are in the order of the signer address
    sigs.sort((s1, s2) => Buffer.from(s2.addr, 'hex') < Buffer.from(s1.addr, 'hex') ? 1 : -1);
	const fullSig = multiSigToBytes(sigs.map(s => s.sig));
	console.log('    Full signature is hash: ', msg.hash, 'sig:', fullSig);
	msg.signature = fullSig;
	return msg;
}
