<div align="center">
    <img src="assets/floweave-text.png" alt="Floweave Text" width="500"/>
    <br/>
    <img src="assets/floweave-flow.svg" width="100%" alt="Floweave Flow"/>
    <br/>
    <br/>
    <img src="https://img.shields.io/static/v1?style=for-the-badge&label=Platform&message=Linux&colorA=1e1e2e&colorB=f9e2af&logo=linux&logoColor=f9e2af">
    <a href="https://github.com/ITx-prash/floweave/releases"><img src="https://img.shields.io/github/v/release/ITx-prash/floweave?style=for-the-badge&label=Release&colorA=1e1e2e&colorB=a6e3a1&logo=githubactions&logoColor=a6e3a1"></a>
    <a href="https://github.com/ITx-prash/floweave/issues"><img src="https://img.shields.io/static/v1?style=for-the-badge&label=&message=Report%20Issue&colorA=1e1e2e&colorB=89dceb&logo=gitbook&logoColor=89dceb"></a>
</div>

---

<!-- <br/> -->

**Floweave** is a lightweight terminal utility that extends your Linux desktop to a virtual display, allowing you to use any device as a wireless second monitor via VNC.

## ✨ Features

- **Wireless Display:** Extend your Xorg desktop to any device using VNC.
- **Configurable Output:** Adjust resolution, position, and scaling as needed.
- **Interactive CLI:** Clean, intuitive terminal interface for managing sessions.
- **No Cables Required:** Works seamlessly over your local WiFi network.

## 📋 Requirements

- Linux with an **Xorg (X11)** session — Wayland is not supported
- Both your laptop and second device on the **same WiFi network**
- A **VNC client** app on your second device — e.g. [AVNC](https://github.com/gujjwal00/avnc) (Android), [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/) (iOS/Android/desktop)

## 🚀 Installation

### Quick Start

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/ITx-prash/floweave.git
    cd floweave
    ```

2.  **Run the installer:**

    ```bash
    ./install.sh
    ```

    > The installer automatically handles all required dependencies.

3.  **Launch Floweave:**

    ```bash
    floweave
    ```

4.  **Connect your device:** Open your VNC client app, enter the IP address and port shown by Floweave (e.g. `192.168.1.x:5900`), and connect.

> [!IMPORTANT]
> <em>If the `floweave` command is not found, restart your terminal or run `source ~/.bashrc` (or your shell's config file) to update your PATH.</em>

## 📖 Usage

Floweave offers both a rich interactive menu and a fast command-line interface.

### Interactive Menu

Simply run `floweave` to open the main dashboard:

```bash
floweave
```

From here, you can start/stop the service, configure settings, and view connection details.

### Command Line Interface

For fast operations and scripting:

| Command            | Description                                    |
| :----------------- | :--------------------------------------------- |
| `floweave start`   | Start the virtual display and VNC server       |
| `floweave stop`    | Stop the server and remove the virtual display |
| `floweave config`  | Open the configuration wizard                  |
| `floweave help`    | Show help information                          |
| `floweave version` | Display current version                        |

---

### Uninstall

To remove Floweave from your system:

```bash
rm -rf ~/.local/share/floweave
rm ~/.local/bin/floweave
```

<p align="center">
	<img src="assets/coder.png" height="150" alt="Coder illustration"/>
	<br/>
	<em>Crafted with 💚 on GNU/Linux</em>
	<br/>
	Copyright &copy; 2025-present <a href="https://github.com/ITx-prash" target="_blank">Prashant Adhikari</a>
	<br/><br/>
	<a href="https://github.com/ITx-prash/floweave/blob/main/LICENSE"><img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&logoColor=a6e3a1&colorA=1e1e2e&colorB=a6e3a1"/></a>
</p>
