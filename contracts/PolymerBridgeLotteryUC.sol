//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./base/UniversalChanIbcApp.sol";

contract PolymerBridgeLotteyUC is UniversalChanIbcApp {
    
    uint[] private luckyTickets = [24, 11, 98];
    mapping (uint => bool) private luckyTicketsMap;
    mapping (address => uint) private userTicket;
    mapping (uint => address[]) private luckyUsers;

    constructor(address _middleware) UniversalChanIbcApp(_middleware) {
        for (uint i = 0; i < luckyTickets.length; i++) {
            luckyTicketsMap[luckyTickets[i]] = true;
        }
    }

    function getAllLuckyUsers() external view onlyOwner returns (address[] memory) {
        address[] memory _luckyUsers = new address[](0);
        for (uint i = 0; i < luckyTickets.length; i++) {
            if (luckyUsers[luckyTickets[i]].length == 0) continue;
            for (uint j = 0; j < luckyUsers[luckyTickets[i]].length; j++) {
                _luckyUsers.push(luckyUsers[luckyTickets[i]][j]);
            }
        }
        return _luckyUsers;
    }

    // IBC logic

    /**
     * @dev Sends a packet with the caller's address over the universal channel.
     * @param destPortAddr The address of the destination application.
     * @param channelId The ID of the channel to send the packet to.
     * @param timeoutSeconds The timeout in seconds (relative).
     */
    function sendUniversalPacket(
        address destPortAddr,
        bytes32 channelId,
        uint64 timeoutSeconds,
        uint ticket
    ) external {
        bytes memory payload = abi.encode(msg.sender, ticket);

        uint64 timeoutTimestamp = uint64((block.timestamp + timeoutSeconds) * 1000000000);

        IbcUniversalPacketSender(mw).sendUniversalPacket(
            channelId, IbcUtils.toBytes32(destPortAddr), payload, timeoutTimestamp
        );
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and returns and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *
     * @param channelId the ID of the channel (locally) the packet was received on.
     * @param packet the Universal packet encoded by the source and relayed by the relayer.
     */
    function onRecvUniversalPacket(bytes32 channelId, UniversalPacket calldata packet)
        external
        override
        onlyIbcMw
        returns (AckPacket memory ackPacket)
    {
        recvedPackets.push(UcPacketWithChannel(channelId, packet));

        (address sender, uint64 ticket) = abi.decode(packet.appData, (address, uint));
        
        userTicket[sender] = ticket;
        if (luckyTicketsMap[ticket]) {
            luckyUsers[ticket].push(sender);
        }

        return AckPacket(true, abi.encode(0));
    }

    /**
     * @dev Packet lifecycle callback that implements packet acknowledgment logic.
     *      MUST be overriden by the inheriting contract.
     *
     * @param channelId the ID of the channel (locally) the ack was received on.
     * @param packet the Universal packet encoded by the source and relayed by the relayer.
     * @param ack the acknowledgment packet encoded by the destination and relayed by the relayer.
     */
    function onUniversalAcknowledgement(bytes32 channelId, UniversalPacket memory packet, AckPacket calldata ack)
        external
        override
        onlyIbcMw
    {
        ackPackets.push(UcAckWithChannel(channelId, packet, ack));
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and return and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *      NOT SUPPORTED YET
     *
     * @param channelId the ID of the channel (locally) the timeout was submitted on.
     * @param packet the Universal packet encoded by the counterparty and relayed by the relayer
     */
    function onTimeoutUniversalPacket(bytes32 channelId, UniversalPacket calldata packet) external override onlyIbcMw {
        timeoutPackets.push(UcPacketWithChannel(channelId, packet));
        // do logic
    }
}
