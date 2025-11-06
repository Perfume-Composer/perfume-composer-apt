# perfume-composer-apt
Debian APT repository for Professional Perfume Composer software
Welcome to the official **APT repository** for **Professional Perfume Composer** — a cross-platform application designed for professional perfumers to create, manage, and analyze fragrance formulas.

This repository allows **Linux Mint**, **Ubuntu**, and **Debian** users to install and update *Perfume Composer* directly from the system's **Software Manager** or via the terminal using `apt`.

---

## 🧴 Installation

To add this repository and install Perfume Composer on your system, run:

```bash
curl -fsSL https://perfume-composer.github.io/perfume-composer-apt/PERFUME-COMPOSER.gpg.key | \
sudo gpg --dearmor -o /usr/share/keyrings/perfume-composer.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/perfume-composer.gpg] \
https://perfume-composer.github.io/perfume-composer-apt stable main" | \
sudo tee /etc/apt/sources.list.d/perfume-composer.list > /dev/null

sudo apt update
sudo apt install perfumecomposer

