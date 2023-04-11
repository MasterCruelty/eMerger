[![code_size](https://img.shields.io/github/languages/code-size/MasterCruelty/eMerger)](https://img.shields.io/github/languages/code-size/MasterCruelty/eMerger)
[![issues](https://img.shields.io/github/issues/MasterCruelty/eMerger)](https://img.shields.io/github/issues/MasterCruelty/eMerger)
[![top_language](https://img.shields.io/github/languages/top/MasterCruelty/eMerger)](https://img.shields.io/github/languages/top/MasterCruelty/eMerger)
[![maintainability](https://sonarcloud.io/api/project_badges/measure?project=MasterCruelty_eMerger&metric=sqale_rating)](https://sonarcloud.io/api/project_badges/measure?project=MasterCruelty_eMerger&metric=sqale_rating)
[![quality_gate](https://sonarcloud.io/api/project_badges/measure?project=MasterCruelty_eMerger&metric=alert_status)](https://sonarcloud.io/api/project_badges/measure?project=MasterCruelty_eMerger&metric=alert_status)
[![commit_activity](https://img.shields.io/github/commit-activity/w/MasterCruelty/eMerger)](https://img.shields.io/github/commit-activity/w/MasterCruelty/eMerger)
[![commits_since_release](https://img.shields.io/github/commits-since/MasterCruelty/emerger/latest?color=44CC11&style=flat-square)](https://img.shields.io/github/commits-since/MasterCruelty/emerger/latest?color=44CC11&style=flat-square)

<h1>eMerger</h1>
<p align="center">
    <img src="./src/logo/big_name.png" alt="logo">
</p>

<h2>What is it?</h2>
eMerger is a simple script to clean update your system and your packages by just typing <code>up</code> in your terminal!<br>

<h2>Systems tested and working</h2>
<ul>
    <li>Arch Linux</li>
    <li>Debian</li>
    <li>EndeavourOS</li>
    <li>Fedora</li>
    <li>Kali</li>
    <li>Manjaro</li>
    <li>Raspbian</li>
    <li>Termux</li>
    <li>Ubuntu</li>
</ul>

<h2>Systems tested and not working (help wanted)</h2>
<ul>
    <li>CentOS</li>
</ul>

<h2>Supported package managers</h2>
<ul>
    <li>apt</li>
    <li>apt-get</li>
    <li>dnf</li>
    <li>emerge</li>
    <li>flatpak</li>
    <lI>nixos</li>
    <li>pacman</li>
    <li>pkg</li>
    <li>rpm</li>
    <li>snap</li>
    <li>yay</li>
    <li>yum</li>
    <li>zypper</li>
</ul>

---

<h2>Install</h2>
<ol>
    <li> Run <code>./setup.sh</code> </li>
    <li> Run <code>up</code></li>
</ol>
If you cloned using root privileges, and you want to execute without them, remember to run: <code>sudo chown -R yourusername .</code>
<h2>Uninstall</h2>
<ol>
    <li>Run <code>./uninstall.sh</code></li>
</ol>
<h2>Update</h2>
You have three options:
<ol>
    <li>Run <code>./update.sh</code></li>
    <li>Run <code>up -up</code></li>
    <li>Run <code>up -au</code> to set a cronjob</li>
</ol>
<h2>Usage</h2>
eMerger comes with inline arguments: just type <code>up -help</code> to explore them.

---

<h2>Contribute</h2>
<a href="https://github.com/MasterCruelty/eMerger/blob/main/CONTRIBUTING.md">How to contribute</a><br>
<h2>Issue</h2>
Is there a problem? 🖥️<br>
Your package manager is not listed? 🖥️<br>
Feel free to open an issue. Try to explain exactly what happens and if possible post errors or outputs you managed to retrieve.<br>
<h2>License</h2>
 This project license can be found in <code>./LICENSE</code>
<h2>External projects used</h2>
<a href="https://github.com/chubin/wttr.in">wttr.in</a>
