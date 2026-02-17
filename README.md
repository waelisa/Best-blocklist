# **🛡️ Wael's Best P2P Blocklist (Super-List)**

Finding a complete blocklist for torrenting can be a massive pain. You’re never quite sure which one to pick. There are a ton of lists out there, but they’re all for different purposes. No single list gives you complete protection: one might block spammers, another might shield you from government snooping, but almost none of them combine everything you actually need.

**This is my Safe List.** I built this because other "massive" blacklists block too many good IPs—including legitimate seedboxes—which kills your download speeds and ratio.

My list focuses on what matters: **Banning bad peers and known copyright-trolling IPs, while keeping the "good" P2P traffic flowing.**

**"Keep sharing, stay safe, and have fun."** — Wael Isa

## **✨ Features**

*   **Industrial Grade Aggregation:** Combines high-quality sources (Naunter, iBlocklist, and more) into one master file.
*   **Precision Filtering:** Removes redundant IP ranges that cause "False Positives" on seedboxes.
*   **Transmission Ready:** Automatically detects your Transmission directory and updates the blocklist.
*   **Clean & Optimized:** Advanced deduplication engine keeps the list lean and fast.
*   **Auto-Dependency:** If you're missing zip or curl, the script can install them for you.

## **🚀 Quick Start**

### **1. Clone the repository**

Bash

git clone https://github.com/waelisa/Best-blocklist.git cd Best-blocklist

### **2. Make the script executable**

Bash

chmod +x Blocklist-builder.sh

### **3. Run the Builder**

You can run it simply to build the list, or use the --install flag to ensure your system has all the required tools.

Bash

# Standard build ./Blocklist-builder.sh # Build + Install missing dependencies (zip, curl, etc.) sudo ./Blocklist-builder.sh --install

## **⚙️ Advanced Usage**

Plaintext

Options:

-h, --help Show help message

-c, --clean Clean work directory and exit

-v, --version Show version information

-p, --paths Show detected Transmission paths

--no-install Disable auto-dependency installation

## **📂 File Output**

*   **bt_blocklist.p2p**: The raw plaintext list (PeerGuardian format).
*   **bt_blocklist.zip**: A compressed version for easy sharing and backups.

## **🤝 Contributing**

I built this for the community. If you have better sources, find a bad IP that should be blocked, or have ideas to make the script faster, please **open an issue** or **submit a pull request**.

**Website:** [www.wael.name](https://www.wael.name)

**Project Link:** [https://github.com/waelisa/Best-blocklist](https://github.com/waelisa/Best-blocklist)

### **⚠️ Disclaimer**

_This blocklist is a layer of protection, not a magic bullet. For 100% privacy, always use a VPN or a Seedbox alongside this list._

[Donate link – PayPal](https://www.paypal.me/WaelIsa)
