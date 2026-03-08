import { connectWallet } from "./wallet.js"

const connectBtn = document.querySelector(".connect-wallet")

console.log("Button element:", connectBtn)

if (connectBtn) {
  connectBtn.addEventListener("click", () => {
    console.log("Connect button clicked")
    connectWallet()
  })
}

console.log("Flesh Nuggets site loaded")