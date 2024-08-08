import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { GeneralTaxDistributorUpgradable } from "../../typechain-types";
import GTDProxyModule from "../../ignition/modules/GTDProxyModule";
import hre from "hardhat";


describe("GTD UUPS", function () {
    const lowThresholdX1000 = 500;
    let gtd,
        proxy,
        proxiedGtd: GeneralTaxDistributorUpgradable;

    async function deploymentFixture() {
        ({ proxy, gtd } = await hre.ignition.deploy(GTDProxyModule, {
            parameters: {
                GTDProxyModule: {
                    lowThresholdX1000
                }
            }
        }));

        proxiedGtd = gtd.attach(proxy.target) as any as GeneralTaxDistributorUpgradable;
    }

    describe("Deployment", function () {
        beforeEach("Deploy", async function () {
            await loadFixture(deploymentFixture);
        });
        
        it("Should deploy correctly", async function () {
            // Checks if owner() is accessible through proxy and is correctly set to the first default account
            expect(await proxiedGtd.owner()).to.be.eq(await (await hre.ethers.getSigners())[0].getAddress());
            
            // Check low threshold
            expect(await proxiedGtd.lowThresholdX1000()).to.be.eq(lowThresholdX1000);
        });

        // TODO: Copy over some tests from original tests in test/taxing/GeneralTaxDistributor.ts
    });
});
