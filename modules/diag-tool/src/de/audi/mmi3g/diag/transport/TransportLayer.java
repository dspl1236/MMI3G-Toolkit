/**
 * Transport Layer Interface — Abstracts the physical communication.
 *
 * The diagnostic app doesn't care HOW it talks to ECUs.
 * Implementations handle the specifics:
 *
 * - SimulatedTransport: For desktop testing (no car needed)
 * - VNCITransport: VNCI 6154a via DoIP over USB Ethernet
 * - CANTransport: Direct CAN bus via /dev/can (if available)
 * - V850Transport: Through the IOC chip via HPIPC/SPI
 *
 * All implementations handle ISO-TP (ISO 15765-2) framing
 * for multi-frame UDS messages.
 *
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag.transport;

public interface TransportLayer {

    /**
     * Connect to a specific ECU by its diagnostic address.
     *
     * VAG module addresses (same as VCDS):
     *   0x01 = Engine ECU
     *   0x02 = Transmission
     *   0x03 = ABS/ESP
     *   0x08 = HVAC
     *   0x09 = Central Electrics
     *   0x15 = Airbag
     *   0x17 = Instrument Cluster
     *   0x19 = CAN Gateway
     *   0x25 = Immobilizer
     *   0x44 = Steering Assist
     *   0x46 = Central Comfort
     *   0x5F = MMI / Information Electronics
     *   0x65 = Tire Pressure
     *   0x76 = Park Assist
     *
     * @param moduleAddress The VAG module address (0x01-0xFF)
     * @return true if connection established
     */
    boolean connect(int moduleAddress);

    /**
     * Disconnect from the current ECU.
     */
    void disconnect();

    /**
     * Send a UDS request and wait for a response.
     *
     * @param request Raw UDS request bytes (SID + data)
     * @param timeoutMs Maximum wait time in milliseconds
     * @return Raw UDS response bytes, or null on timeout
     */
    byte[] sendAndReceive(byte[] request, int timeoutMs);

    /**
     * Check if the transport is currently connected.
     */
    boolean isConnected();

    /**
     * Get the name of this transport implementation.
     */
    String getName();

    /**
     * Close the transport and release resources.
     */
    void close();
}
