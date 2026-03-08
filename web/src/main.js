import { connectWallet, getConnectedAddress, shortAddress } from "./wallet.js"

const connectBtn = document.querySelector(".connect-wallet")

console.log("Button element:", connectBtn)

async function updateWalletButton() {
  if (!connectBtn) return

  const address = await getConnectedAddress()

  if (address) {
    connectBtn.textContent = shortAddress(address)
    connectBtn.title = address
  } else {
    connectBtn.textContent = "CONNECT WALLET"
    connectBtn.title = "Connect wallet"
  }
}

if (connectBtn) {
  connectBtn.addEventListener("click", async () => {
    console.log("Connect button clicked")
    connectWallet()

    let tries = 0
    const poll = setInterval(async () => {
      tries += 1
      await updateWalletButton()

      if (tries >= 20) {
        clearInterval(poll)
      }
    }, 500)
  })
}

setInterval(updateWalletButton, 1000)

updateWalletButton()

console.log("Flesh Nuggets site loaded")