import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const gtdProxyModule = buildModule("GTDProxyModule", (m) => {
	const gtd = m.contract("GeneralTaxDistributorUpgradable");
	const owner = m.getAccount(0)
	const lowThresholdX1000 = m.getParameter("lowThresholdX1000");
	const initializeCalldata = m.encodeFunctionCall(gtd, "initialize", [
		owner,
		owner,
		lowThresholdX1000
	]);

	const proxy = m.contract("ERC1967Proxy", [
		gtd,
		initializeCalldata
	]);

	return {proxy, gtd}
})

export default gtdProxyModule;
