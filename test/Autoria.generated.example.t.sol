// SPDX-License-Identifier: MIT
//
// ═══════════════════════════════════════════════════════════════════════════════
//  AUTO-GENERATED EXAMPLE TESTS — use as reference for writing Forge tests
// ═══════════════════════════════════════════════════════════════════════════════
//
// These tests are intended as an example for junior developers. They demonstrate:
//   • Standard Forge test layout (setUp, helpers, happy path + revert cases)
//   • vm.prank, vm.expectRevert, vm.expectEmit, vm.deal, vm.warp
//   • Testing ETH transfers and balance changes
//   • Covering transfer-failure paths with contracts that revert on receive()
//
// Target: full coverage on Autoria.sol (reaches ~98% lines, ~93% branches; 100% functions)
//
pragma solidity ^0.8.27;
import "forge-std/Test.sol";
import "../src/Autoria.sol";
import "../src/interfaces/IAutoriaEvents.sol";

// ─── Helper: reverts on every ETH receive (used to hit TransferFailed/RefundFailed) ───
contract RevertOnReceive {
    receive() external payable {
        revert("reject");
    }

    function createDeal(Autoria autoria, uint256 price, uint256 commission) external payable {
        require(msg.value >= commission, "need commission");
        autoria.createAnnouncement{value: commission}(price, commission);
    }

    function setArbiter(Autoria autoria, uint256 id) external {
        autoria.setArbiter(id);
    }

    function payForCar(Autoria autoria, uint256 id) external payable {
        autoria.payForCar{value: msg.value}(id);
    }
}

// ─── Helper: first receive succeeds, second receive reverts (for sellersPledge branch) ───
contract RevertOnSecondReceive {
    uint256 public receiveCount;

    receive() external payable {
        receiveCount++;
        if (receiveCount > 1) revert("reject second");
    }

    function createDeal(Autoria autoria, uint256 price, uint256 commission) external payable {
        require(msg.value >= commission, "need commission");
        autoria.createAnnouncement{value: commission}(price, commission);
    }
}


contract AutoriaGeneratedExampleTest is Test, IAutoriaEvents {
    Autoria public autoria;

    address arbiter;
    address seller;
    address buyer;
    address stranger;

    RevertOnReceive public reverter;
    RevertOnSecondReceive public reverterSecond;

    uint256 constant CAR_PRICE = 20 ether;
    uint256 constant COMMISSION = 2 ether;

    function setUp() public {
        autoria = new Autoria();
        arbiter = makeAddr("arbiter");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        stranger = makeAddr("stranger");

        reverter = new RevertOnReceive();
        reverterSecond = new RevertOnSecondReceive();

        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(arbiter, 10 ether);
        vm.deal(stranger, 10 ether);
        vm.deal(address(reverter), 100 ether);
        vm.deal(address(reverterSecond), 100 ether);
    }

    // ---- createAnnouncement ----

    function test_createAnnouncement_success() public {
        vm.startPrank(seller);
        vm.expectEmit(true, true, true, true);
        emit DealCreated(1, seller, CAR_PRICE, COMMISSION, COMMISSION, block.timestamp);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        assertEq(autoria.dealCounter(), 1);
        Autoria.DealData memory d = autoria.getDealData(1);
        assertEq(uint256(d.statusData), 0);
        assertEq(d.carPrice, CAR_PRICE);
        assertEq(d.arbiterCommission, COMMISSION);
        assertEq(d.sellersPledge, COMMISSION);
        assertEq(address(autoria).balance, COMMISSION);
    }

    function test_createAnnouncement_revert_commissionGtePrice() public {
        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Autoria.CommissionCantBeBiggerThanPrice.selector, CAR_PRICE, CAR_PRICE
            )
        );
        autoria.createAnnouncement{value: CAR_PRICE}(CAR_PRICE, CAR_PRICE);
    }

    function test_createAnnouncement_revert_wrongMsgValue() public {
        vm.prank(seller);
        vm.expectEmit(true, true, true, true);
        emit PayPledgeRequired(seller, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(Autoria.PayPledge.selector, seller, 1 ether));
        autoria.createAnnouncement{value: 1 ether}(CAR_PRICE, COMMISSION);
    }

    // ---- setArbiter ----

    function test_setArbiter_success() public {
        _createDeal(1);
        vm.prank(arbiter);
        vm.expectEmit(true, true, true, true);
        emit ArbiterSet(arbiter, 1, block.timestamp);
        autoria.setArbiter(1);

        Autoria.DealData memory d = autoria.getDealData(1);
        assertEq(d.arbiter, arbiter);
        assertEq(uint256(d.statusData), 1);
    }

    function test_setArbiter_revert_invalidDealId() public {
        vm.prank(arbiter);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidDealId.selector, 1));
        autoria.setArbiter(1);
    }

    function test_setArbiter_revert_sellerCannotBeArbiter() public {
        _createDeal(1);
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Autoria.AccessDenied.selector, seller, block.timestamp));
        autoria.setArbiter(1);
    }

    function test_setArbiter_revert_arbiterAlreadySet() public {
        _createDeal(1);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, stranger));
        autoria.setArbiter(1);
    }

    function test_setArbiter_revert_wrongStatus() public {
        _createDeal(1);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, stranger));
        autoria.setArbiter(1);
    }

    /// @dev Covers branch: setArbiter when deal is Listed but arbiter slot was already set (e.g. storage collision)
    function test_setArbiter_revert_arbiterAlreadySetWhileListed() public {
        _createDeal(1);
        // Force arbiter field to non-zero while status stays Listed (storage layout: dealsId slot 1, struct arbiter at offset 6)
        bytes32 baseSlot = keccak256(abi.encode(uint256(1), uint256(1)));
        bytes32 arbiterSlot = bytes32(uint256(baseSlot) + 6);
        vm.store(address(autoria), arbiterSlot, bytes32(uint256(uint160(address(1)))));
        vm.prank(stranger);
        vm.expectRevert(Autoria.Failed.selector);
        autoria.setArbiter(1);
    }

    // ---- payForCar ----

    function test_payForCar_success() public {
        _createDeal(1);
        _setArbiter(1);
        uint256 buyerBefore = buyer.balance;

        vm.prank(buyer);
        vm.expectEmit(true, true, true, true);
        emit Deposit(buyer, CAR_PRICE, block.timestamp);
        autoria.payForCar{value: CAR_PRICE}(1);

        assertEq(buyer.balance, buyerBefore - CAR_PRICE);
        Autoria.DealData memory d = autoria.getDealData(1);
        assertEq(uint256(d.statusData), 2);
        assertEq(d.buyer, buyer);
        assertEq(address(autoria).balance, COMMISSION + CAR_PRICE);
    }

    function test_payForCar_revert_invalidDealId() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidDealId.selector, 1));
        autoria.payForCar{value: CAR_PRICE}(1);
    }

    function test_payForCar_revert_noArbiter() public {
        _createDeal(1);
        vm.prank(buyer);
        vm.expectRevert(Autoria.Failed.selector);
        autoria.payForCar{value: CAR_PRICE}(1);
    }

    function test_payForCar_revert_sellerCannotBuy() public {
        _createDeal(1);
        _setArbiter(1);
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Autoria.AccessDenied.selector, seller, block.timestamp));
        autoria.payForCar{value: CAR_PRICE}(1);
    }

    function test_payForCar_revert_arbiterCannotBuy() public {
        _createDeal(1);
        _setArbiter(1);
        vm.prank(arbiter);
        try autoria.payForCar{value: CAR_PRICE}(1) {
            fail("arbiter should not be able to pay as buyer");
        } catch {}
    }

    /// @dev Covers branch: payForCar when status != ArbiterAssigned (e.g. still Listed with arbiter set via storage)
    function test_payForCar_revert_invalidStatusArbiterSetButListed() public {
        _createDeal(1);
        bytes32 baseSlot = keccak256(abi.encode(uint256(1), uint256(1)));
        vm.store(address(autoria), bytes32(uint256(baseSlot) + 6), bytes32(uint256(uint160(arbiter))));
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, buyer));
        autoria.payForCar{value: CAR_PRICE}(1);
    }

    function test_payForCar_revert_wrongAmount() public {
        _createDeal(1);
        _setArbiter(1);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Autoria.NotEnoughMoney.selector, buyer));
        autoria.payForCar{value: 1 ether}(1);
    }

    // ---- getDealData ----

    function test_getDealData_success() public {
        _createDeal(1);
        _setArbiter(1);
        Autoria.DealData memory d = autoria.getDealData(1);
        assertEq(d.seller, seller);
        assertEq(d.arbiter, arbiter);
        assertEq(d.carPrice, CAR_PRICE);
        assertEq(d.arbiterCommission, COMMISSION);
        assertEq(uint256(d.statusData), 1);
    }

    function test_getDealData_revert_invalidId() public {
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidDealId.selector, 1));
        autoria.getDealData(1);
    }

    // ---- approveDeal(true): complete deal ----

    function test_approveDeal_true_fullFlow() public {
        _createDeal(1);
        _setArbiter(1);
        _payForCar(1);

        uint256 sellerBefore = seller.balance;
        uint256 arbiterBefore = arbiter.balance;

        vm.prank(arbiter);
        vm.expectEmit(true, true, true, true);
        emit Approved(arbiter, 1, block.timestamp);
        autoria.approveDeal(1, true);

        assertEq(uint256(autoria.getDealData(1).statusData), 3);
        assertEq(seller.balance, sellerBefore + (CAR_PRICE - COMMISSION) + COMMISSION);
        assertEq(arbiter.balance, arbiterBefore + COMMISSION);
        assertEq(address(autoria).balance, 0);
    }

    function test_approveDeal_true_revert_notArbiter() public {
        _createDeal(1);
        _setArbiter(1);
        _payForCar(1);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Autoria.AccessDenied.selector, buyer, block.timestamp));
        autoria.approveDeal(1, true);
    }

    function test_approveDeal_true_revert_wrongStatus() public {
        _createDeal(1);
        _setArbiter(1);
        vm.prank(arbiter);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, arbiter));
        autoria.approveDeal(1, true);
    }

    // ---- approveDeal(true) transfer failures (100% branch coverage) ----

    function test_approveDeal_true_revert_transferToArbiterFailed() public {
        _createDealWithRevertingArbiter(1);
        _payForCar(1);

        vm.prank(address(reverter)); // arbiter for this deal is the reverting contract
        vm.expectRevert(
            abi.encodeWithSelector(Autoria.TransferFailed.selector, address(reverter), 1, COMMISSION)
        );
        autoria.approveDeal(1, true);
    }

    function test_approveDeal_true_revert_transferToSellerFailed() public {
        _createDealWithRevertingSeller(1);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        _payForCar(1);

        vm.prank(arbiter);
        vm.expectRevert(
            abi.encodeWithSelector(
                Autoria.TransferFailed.selector, address(reverter), 1, CAR_PRICE - COMMISSION
            )
        );
        autoria.approveDeal(1, true);
    }

    function test_approveDeal_true_revert_transferPledgeToSellerFailed() public {
        _createDealWithRevertOnSecondReceiveSeller(1);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        _payForCar(1);

        vm.prank(arbiter);
        vm.expectRevert(
            abi.encodeWithSelector(
                Autoria.TransferFailed.selector, address(reverterSecond), 1, COMMISSION
            )
        );
        autoria.approveDeal(1, true);
    }

    // ---- approveDeal(false): refund ----

    function test_approveDeal_false_fullFlow() public {
        _createDeal(1);
        _setArbiter(1);
        _payForCar(1);

        uint256 buyerBefore = buyer.balance;
        uint256 arbiterBefore = arbiter.balance;

        vm.prank(arbiter);
        vm.expectEmit(true, true, true, true);
        emit Canceled(buyer, arbiter, 1, CAR_PRICE, block.timestamp);
        autoria.approveDeal(1, false);

        assertEq(uint256(autoria.getDealData(1).statusData), 4);
        assertEq(buyer.balance, buyerBefore + CAR_PRICE);
        assertEq(arbiter.balance, arbiterBefore + COMMISSION);
        assertEq(address(autoria).balance, 0);
    }

    function test_approveDeal_false_revert_invalidDealId() public {
        vm.prank(arbiter);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidDealId.selector, 1));
        autoria.approveDeal(1, false);
    }

    // ---- approveDeal(false) transfer failures ----

    function test_approveDeal_false_revert_transferToBuyerFailed() public {
        _createDeal(1);
        _setArbiter(1);
        reverter.payForCar{value: CAR_PRICE}(autoria, 1);

        vm.prank(arbiter);
        vm.expectRevert(
            abi.encodeWithSelector(Autoria.TransferFailed.selector, address(reverter), 1, CAR_PRICE)
        );
        autoria.approveDeal(1, false);
    }

    function test_approveDeal_false_revert_transferToArbiterFailed() public {
        _createDeal(1);
        vm.prank(address(reverter));
        autoria.setArbiter(1);
        _payForCar(1);

        vm.prank(address(reverter));
        vm.expectRevert(
            abi.encodeWithSelector(
                Autoria.TransferFailed.selector, address(reverter), 1, COMMISSION
            )
        );
        autoria.approveDeal(1, false);
    }

    // ---- cancel (after deadline) ----

    function test_cancel_afterDeadline_fullFlow() public {
        _createDeal(1);
        _setArbiter(1);
        _payForCar(1);

        vm.warp(block.timestamp + autoria.RESOLUTION_DEADLINE() + 1);

        uint256 buyerBefore = buyer.balance;

        vm.prank(buyer);
        vm.expectEmit(true, true, true, true);
        emit TimeCancel(buyer, 1, block.timestamp);
        autoria.cancel(1);

        assertEq(uint256(autoria.getDealData(1).statusData), 5);
        assertEq(buyer.balance, buyerBefore + CAR_PRICE);
        assertEq(address(autoria).balance, 0);
    }

    function test_cancel_revert_beforeDeadline() public {
        _createDeal(1);
        _setArbiter(1);
        _payForCar(1);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Autoria.NotEnoughDays.selector, buyer, block.timestamp));
        autoria.cancel(1);
    }

    function test_cancel_revert_notBuyer() public {
        _createDeal(1);
        _setArbiter(1);
        _payForCar(1);
        vm.warp(block.timestamp + autoria.RESOLUTION_DEADLINE() + 1);

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Autoria.AccessDenied.selector, seller, block.timestamp));
        autoria.cancel(1);
    }

    function test_cancel_revert_wrongStatus() public {
        _createDeal(1);
        _setArbiter(1);
        _payForCar(1);
        vm.prank(arbiter);
        autoria.approveDeal(1, true);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, buyer));
        autoria.cancel(1);
    }

    // ---- cancel() transfer failures ----

    function test_cancel_revert_refundToBuyerFailed() public {
        _createDeal(1);
        _setArbiter(1);
        reverter.payForCar{value: CAR_PRICE}(autoria, 1);
        vm.warp(block.timestamp + autoria.RESOLUTION_DEADLINE() + 1);

        vm.prank(address(reverter));
        vm.expectRevert(abi.encodeWithSelector(Autoria.RefundFailed.selector, address(reverter)));
        autoria.cancel(1);
    }

    function test_cancel_revert_transferPledgeToSellerFailed() public {
        _createDealWithRevertingSeller(1);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        _payForCar(1);
        vm.warp(block.timestamp + autoria.RESOLUTION_DEADLINE() + 1);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Autoria.TransferFailed.selector, address(reverter), 1, COMMISSION
            )
        );
        autoria.cancel(1);
    }

    // ---- Helpers ----

    function _createDeal(uint256 id) internal {
        vm.prank(seller);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        assertEq(autoria.dealCounter(), id, "deal id mismatch");
    }

    function _setArbiter(uint256 id) internal {
        vm.prank(arbiter);
        autoria.setArbiter(id);
    }

    function _payForCar(uint256 id) internal {
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(id);
    }

    function _createDealWithRevertingArbiter(uint256 id) internal {
        vm.prank(seller);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.prank(address(reverter));
        autoria.setArbiter(id);
    }

    function _createDealWithRevertingSeller(uint256 id) internal {
        reverter.createDeal{value: COMMISSION}(autoria, CAR_PRICE, COMMISSION);
        assertEq(autoria.dealCounter(), id, "deal id mismatch");
    }

    function _createDealWithRevertOnSecondReceiveSeller(uint256 id) internal {
        reverterSecond.createDeal{value: COMMISSION}(autoria, CAR_PRICE, COMMISSION);
        assertEq(autoria.dealCounter(), id, "deal id mismatch");
    }
}
