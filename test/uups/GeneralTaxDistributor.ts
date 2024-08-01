import {
    time,
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import GTDProxyModule from "../../ignition/modules/GTDProxyModule";
import hre from "hardhat";

describe("GTD UUPS", function () {

    async function deploymentFixture() {
        const { proxy, gtd } = await hre.ignition.deploy(GTDProxyModule);
        return {proxy, gtd}
    }

    describe("Deployment", function () {
        // TODO: copy over some test cases
        it("Should deploy correctly", async function () {
            const { gtd, proxy } = await loadFixture(deploymentFixture);
            console.log('GTD address is', gtd.target);
            console.log('Proxy address is', proxy.target);
        });
    });
});
