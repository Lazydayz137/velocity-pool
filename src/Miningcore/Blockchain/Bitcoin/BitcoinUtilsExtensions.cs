using System;
using NBitcoin;
using NBitcoin.DataEncoders;

namespace Miningcore.Blockchain.Bitcoin
{
    public static class BitcoinUtilsExtensions
    {
        public static IDestination GroestlcoinAddressToDestination(string address, Network network)
        {
            try
            {
                // Try to decode as a regular Bitcoin address first
                return BitcoinUtils.AddressToDestination(address, network);
            }
            catch (Exception)
            {
                // If that fails, try to handle it as a Groestlcoin address
                try
                {
                    // For Groestlcoin, we'll create a KeyId directly from the address
                    // This is a simplified approach that might work for basic addresses
                    var decoded = Encoders.Base58.DecodeData(address);

                    // Skip the version byte (first byte)
                    var keyBytes = new byte[20];
                    Array.Copy(decoded, 1, keyBytes, 0, 20);

                    return new KeyId(keyBytes);
                }
                catch (Exception ex)
                {
                    throw new FormatException($"Invalid Groestlcoin address: {ex.Message}", ex);
                }
            }
        }

        public static IDestination GroestlcoinBech32AddressToDestination(string address, Network network)
        {
            try
            {
                // Try to use the BechSegwitAddressToDestination method first
                return BitcoinUtils.BechSegwitAddressToDestination(address, network);
            }
            catch (Exception)
            {
                // If that fails, try to handle it as a Groestlcoin bech32 address
                try
                {
                    // For Groestlcoin bech32, we'll create a WitKeyId directly
                    // This assumes the address is a witness v0 key hash (most common)
                    var encoder = Encoders.Bech32("grs");
                    var decoded = encoder.Decode(address, out var witVersion);

                    return new WitKeyId(decoded);
                }
                catch (Exception ex)
                {
                    throw new FormatException($"Invalid Groestlcoin bech32 address: {ex.Message}", ex);
                }
            }
        }
    }
}
