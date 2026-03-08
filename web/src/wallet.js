import { createAppKit } from "@reown/appkit"
import { EthersAdapter } from "@reown/appkit-adapter-ethers"

const projectId = "b83b0fdc5df0de0f086a89d077dd2ded"

console.log("WALLET JS PROJECT ID:", projectId)

const appkit = createAppKit({
  adapters: [new EthersAdapter()],
  projectId: projectId,
  networks: []
})

export function connectWallet() {
  console.log("OPENING APPKIT WITH PROJECT ID:", projectId)
  appkit.open()
}