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

export function connectWallet() {
  console.log("OPENING APPKIT WITH PROJECT ID:", projectId)
  appkit.open()
}

export async function getConnectedAddress() {
  if (!window.ethereum) return null

  try {
    const accounts = await window.ethereum.request({
      method: "eth_accounts"
    })

    return accounts && accounts.length > 0 ? accounts[0] : null
  } catch (error) {
    console.error("Failed to get connected address:", error)
    return null
  }
}

export function shortAddress(address) {
  if (!address) return "CONNECT WALLET"
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}