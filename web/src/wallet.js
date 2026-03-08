import { createAppKit } from "@reown/appkit"
import { EthersAdapter } from "@reown/appkit-adapter-ethers"
import { avalancheFuji } from "@reown/appkit/networks"

const projectId = "b83b0fdc5df0de0f086a89d077dd2ded"

const appkit = createAppKit({
  adapters: [new EthersAdapter()],
  projectId,
  networks: [avalancheFuji],
  metadata: {
    name: "Flesh Nuggets",
    description: "Web3 roguelike MVP",
    url: window.location.origin,
    icons: [`${window.location.origin}/icon.png`]
  }
})

let currentAddress = null
let currentConnected = false

try {
  appkit.subscribeProvider(({ address, isConnected, error }) => {
    if (error) {
      console.error("Wallet subscription error:", error)
    }

    currentConnected = !!isConnected
    currentAddress = isConnected && address ? address : null

    console.log("AppKit provider state:", {
      address: currentAddress,
      isConnected: currentConnected
    })
  })
} catch (error) {
  console.error("Failed to subscribe to wallet provider:", error)
}

export function connectWallet() {
  console.log("OPENING APPKIT WITH PROJECT ID:", projectId)

  try {
    const address = currentAddress || appkit.getAddress?.() || null
    const connected = currentConnected || !!address

    if (connected && address) {
      // When already connected, let AppKit open the connected/account state
      appkit.open()
    } else {
      // When not connected, open the connect flow
      appkit.open({ view: "Connect", namespace: "eip155" })
    }
  } catch (error) {
    console.error("Failed to open AppKit correctly:", error)
    appkit.open({ view: "Connect", namespace: "eip155" })
  }
}

export function getConnectedAddress() {
  try {
    return currentAddress || appkit.getAddress?.() || null
  } catch (error) {
    console.error("Failed to get connected address:", error)
    return null
  }
}

export function isWalletConnected() {
  try {
    return currentConnected || !!getConnectedAddress()
  } catch (error) {
    console.error("Failed to get wallet connection state:", error)
    return false
  }
}

export function subscribeWallet(callback) {
  try {
    appkit.subscribeProvider(({ address, isConnected, chainId, providerType, error }) => {
      if (error) {
        console.error("Wallet subscription error:", error)
      }

      const safeAddress = isConnected && address ? address : null

      currentConnected = !!isConnected
      currentAddress = safeAddress

      callback({
        address: safeAddress,
        isConnected: !!isConnected,
        chainId,
        providerType
      })
    })
  } catch (error) {
    console.error("Failed to subscribe to wallet provider:", error)
  }
}

export function shortAddress(address) {
  if (!address) return "CONNECT WALLET"
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}