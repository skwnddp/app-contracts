// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/interfaces/IERC6372.sol";

import "./xpNFT_V2.sol";

contract ZetaXPGov is Governor, GovernorSettings, GovernorCountingSimple, GovernorTimelockControl {
    bytes32 public tagValidToVote;
    ZetaXP_V2 public xpNFT;
    uint256 public quorumPercentage; // New state to store the quorum percentage
    uint256 public minLevelToPropose; // New state to store the minimum level required to propose

    constructor(
        ZetaXP_V2 _xpNFT,
        TimelockController _timelock,
        uint256 _quorumPercentage, // Set the quorum percentage (e.g., 4%)
        bytes32 _tag
    )
        Governor("ZetaXPGov")
        GovernorSettings(7200 /* 1 day */, 50400 /* 1 week */, 0)
        GovernorTimelockControl(_timelock)
    {
        xpNFT = _xpNFT;
        quorumPercentage = _quorumPercentage;
        tagValidToVote = _tag;
    }

    function setTagValidToVote(bytes32 _tag) external onlyGovernance {
        tagValidToVote = _tag;
    }

    function setQuorumPercentage(uint256 _quorumPercentage) external onlyGovernance {
        quorumPercentage = _quorumPercentage;
    }

    function setMinLevelToPropose(uint256 _minLevelToPropose) external onlyGovernance {
        minLevelToPropose = _minLevelToPropose;
    }

    function _getLevel(address account) internal view returns (uint256) {
        uint256 tokenId = xpNFT.tokenByUserTag(account, tagValidToVote);
        return xpNFT.getLevel(tokenId);
    }

    // Override the _getVotes function to apply custom weight based on NFT levels
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) internal view override returns (uint256) {
        uint256 level = _getLevel(account);

        // Assign voting weight based on NFT level
        if (level == 1) {
            return 1; // Rosegold
        } else if (level == 2) {
            return 2; // Black
        } else if (level == 3) {
            return 3; // Green
        } else {
            return 0; // Silver cannot vote
        }
    }

    // Manually implement the quorum function to define quorum based on the total percentage of votes
    function quorum(uint256 blockNumber) public view override returns (uint256) {
        uint256 totalSupply = xpNFT.totalSupply(); // Total number of NFTs in circulation
        return (totalSupply * quorumPercentage) / 100; // Quorum calculation based on the percentage
    }

    // Override the _execute function to resolve the conflict
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    // Override the supportsInterface function to resolve the conflict
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Implementation of clock and CLOCK_MODE functions to comply with IERC6372
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public view override returns (string memory) {
        return "mode=timestamp";
    }

    // The rest of the functions required to be overridden by Solidity

    function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal override returns (uint256) {
        uint256 level = _getLevel(account);
        require(level > 0, "ZetaXPGov: invalid NFT level");

        return super._castVote(proposalId, account, support, reason, params);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override(Governor, IGovernor) returns (uint256) {
        uint256 level = _getLevel(msg.sender);
        require(level >= minLevelToPropose, "ZetaXPGov: insufficient level to propose");

        return super.propose(targets, values, calldatas, description);
    }
}
