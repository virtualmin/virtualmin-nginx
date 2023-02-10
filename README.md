

<!-- PROJECT SHIELDS -->

[![Contributors](https://img.shields.io/github/contributors/virtualmin/virtualmin-nginx)](https://github.com/virtualmin/virtualmin-nginx/graphs/contributors)
[![Contributors](https://img.shields.io/github/contributors/virtualmin/virtualmin-nginx)](https://github.com/virtualmin/virtualmin-nginx/graphs/contributors)
[![Forks](https://img.shields.io/github/forks/virtualmin/virtualmin-nginx)](https://github.com/virtualmin/virtualmin-nginx/network/members)
[![Stargazers](https://img.shields.io/github/stars/virtualmin/virtualmin-nginx)](#)
[![Issues](https://img.shields.io/github/issues-raw/virtualmin/virtualmin-nginx)](https://github.com/virtualmin/virtualmin-nginx/issues)
[![MIT License](https://img.shields.io/github/license/virtualmin/virtualmin-nginx)](https://github.com/virtualmin/virtualmin-nginx/blob/master/LICENSE)



# Virtualmin NGINX with Reverse Proxy

A plugin for Webmin to enable NGINX with Virtualmin.<br>
[![Explore the docs »](https://badgen.net/badge/Explore%20the/Docs%20»/)](https://github.com/virtualmin/virtualmin-nginx) 

Questions or issues?<br>
[![Request Feature](https://badgen.net/badge/Request/Feature/cyan)](https://github.com/virtualmin/virtualmin-nginx/issues) 
[![Report Bug](https://badgen.net/badge/Report/Bug/cyan)](https://github.com/virtualmin/virtualmin-nginx/issues) 
 
 

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#supported-systems">Supported Systems</a></li>
        <li><a href="#prerequisites">Prerequisites</a></li>
      </ul>
    </li>
        <li><a href="#installation">Installation</a>
        <ul>
          <li><a href="#install-method-1">Installing from Github</a></li>
          <li><a href="#install-method-2">Installing from File</a></li>
      </ul>
     </li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
  </ol>
</details>


<!-- GETTING STARTED -->
## Getting Started

This is a module for Webmin to use NGINX as a web server and reverse proxy.


### Supported systems

You can find a list of the supported system here: https://www.virtualmin.com/documentation/os-support/

### Prerequisites

To use, you must have Webmin and Virtualmin installed.  You also need to have LEMP installed including NGINX and PHP.

* Installing WebMin: https://webmin.com/download/
* Installing Virtualmin: https://www.virtualmin.com/download/


#### Installing LEMP stack

The list of packages you need to install include:
<ul>
<li>php-fpm</li>
<li>php-mysqlnd </li>
<li>php-gd</li>
<li>php-cli </li>
<li>php-curl </li>
<li>php-mbstring</li>
<li>php-bcmath</li>
<li>php-zip</li>
<li>php-opcache</li>
<li>php-xml</li>
<li>php-json</li>
<li>php-intl</li>
<li>httpd</li>
<li>php</li>
<li>php-cli</li>
</ul>

#### Start NGINX

    systemctl start nginx
    systemctl enable nginx

#### Update firewall

    firewall-cmd --permanent --add-service={http,https}
    firewall-cmd --reload

#### Check NGINX and PHP-FPM are running

    systemctl status nginx
    systemctl status php-fpm

### Simple one-line install of above

On AlmaLinux 8 and 9, CentOS 8, CentOS Stream 8 & 9, and some others, you can install the above using the following one-liner:

    dnf update; dnf install nginx; dnf install php-fpm php-mysqlnd php-gd php-cli php-curl php-mbstring php-bcmath php-zip php-opcache php-xml php-json php-intl httpd php php-cli -y;systemctl start nginx;systemctl enable nginx;firewall-cmd --permanent --add-service={http,https};firewall-cmd --reload;systemctl status nginx;systemctl status php-fpm


<p align="right">(<a href="#readme-top">back to top</a>)</p>


## Installation 

Installing this module is simple. There are two ways to install, either directly from the github repository, or from downloading the file from github and uploading to Webmin through the GUI.

*Note: Do not use the Perl Modules interface or the PHP Module interface, as this is not a Perl module or a PHP module, it is a Webmin module. There is a separate interface for installing Webmin modules.*

#### Install Method 1: Installing from Github

1. Go to the Releases page on github, right-click the latest release .tar.gz release file link, and copy the link (the link should end in .tar.gz).
2. Go to Webmin > Webmin Configuration > Webmin Modules
3. Paste the link into the section: "From HTTP or FTP URL".
4. Click the green Install Module button at the bottom.

#### Install Method 2: Installing from File

1. Download the latest release .tar.gz file.
2. Go to Webmin > Webmin Configuration > Webmin Modules
3. Under the section, "From uploaded file", click the paperclip icon, and find the file you just downloaded from github.
4. Click the green Install Module button at the bottom.

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>