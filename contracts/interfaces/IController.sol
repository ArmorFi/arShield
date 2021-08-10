// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IController {
    function bonus() external view returns (uint256);
    function refFee() external view returns (uint256);
    function governor() external view returns (address);
    function depositAmt() external view returns (uint256);
    function beneficiary() external view returns (address payable);
    function emitAction(
        address _user,
        address _referral,
        address _shield,
        address _pToken,
        uint256 _amount,
        uint256 _refFee,
        bool _mint
    ) external;
}