# perfume-composer-apt
Debian APT repository for Professional Perfume Composer software
Welcome to the official **APT repository** for **Professional Perfume Composer** — a cross-platform application designed for professional perfumers to create, manage, and analyze fragrance formulas.

This repository allows **Linux Mint**, **Ubuntu**, and **Debian** users to install and update *Perfume Composer* directly from the system's **Software Manager** or via the terminal using `apt`.

---

## 🧴 Installation

To add this repository and install Perfume Composer on your system, run:

```bash
sudo mkdir -p /usr/share/keyrings
wget -qO - https://perfume-composer.github.io/perfume-composer-apt/PERFUME-COMPOSER.gpg.key \
  | sudo tee /usr/share/keyrings/perfume-composer.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/perfume-composer.gpg arch=amd64] \
https://perfume-composer.github.io/perfume-composer-apt stable main" \
| sudo tee /etc/apt/sources.list.d/perfume-composer.list

sudo apt update
sudo apt install perfume-composer

