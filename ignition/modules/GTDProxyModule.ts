import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const gtdProxyModule = buildModule("GTDProxyModule", (m) => {
	const gtd = m.contract("GeneralTaxDistributorUpgradable");

	// ADD INITIALIZATION LOGIC

	const proxy = m.contract("ERC1967Proxy", [
		gtd,
		"0x"
	]);

	return {proxy, gtd}
})

export default gtdProxyModule;
