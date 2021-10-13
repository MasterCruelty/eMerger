<table>
    <tr>
        <th>Code</th>
        <th>Details</th>
    </tr>
        <td>
            <img src="https://img.shields.io/github/languages/code-size/MasterCruelty/eMerger" alt="code size">
            <img src="https://img.shields.io/github/issues/MasterCruelty/eMerger" alt="issues open">
            <img src="https://img.shields.io/github/languages/top/MasterCruelty/eMerger" alt="top language">
        </td>
        <td>
            <img src="https://img.shields.io/github/commit-activity/w/MasterCruelty/eMerger" alt="commit activity">
            <img src="https://img.shields.io/github/contributors/MasterCruelty/eMerger" alt="contributors">
            <img src="https://img.shields.io/github/forks/MasterCruelty/Updater" alt="forks"><br>
            <img src="https://badgen.net/github/release/MasterCruelty/Updater?label=Latest%20release" alt="latest release">
            <img src="https://img.shields.io/github/license/MasterCruelty/eMerger" alt="license">
            <img src="https://img.shields.io/github/stars/MasterCruelty/Updater" alt="stars">
        </td>
</table>

<h1>eMerger</h1>
<img src="./src/logo/big_name.png" alt="logo">

<h2>What is it?</h2>
eMerger is a simple script to clean update your system and your packages by just typing <code>up</code> in your terminal!<br>
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
<ul>
    <li>This project license can be found in <code>./LICENSE</code></li>
    <li><a href="https://github.com/chubin/wttr.in">wttr.in</a>
license can be found under <code>./license/WTTR_LICENSE</code> or
<a href="https://github.com/chubin/wttr.in/blob/master/LICENSE">here</a>.
The project is only used to retrieve weather data.</li>
</ul>
