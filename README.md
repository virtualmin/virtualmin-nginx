
<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]



<h3 align="center">Virtualmin NGINX with Reverse Proxy</h3>

  <p align="center">
    project_description
    <br />
    <a href="https://github.com/virtualmin/virtualmin-nginx"><strong>Explore the docs »</strong></a>
    <br />
    <a href="https://github.com/virtualmin/virtualmin-nginx/issues">Report Bug</a>
    ·
    <a href="https://github.com/virtualmin/virtualmin-nginx/issues">Request Feature</a>
  </p>
</div>



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

This is not an exhaustive list, but supported system may include:
* AlmaLinux 7.x, 8.x, 9.x
* Rocky Linux 7.x, 8.x, 9.x
* Scientific Linux 7.x, 8.x, 9.x
* CentOS 7.x, 8.x
* CentOS Stream 8.x, 9.x
* Debian Linux 10.x
* Oracle Linux 8.x
* RedHat Enterprise Linux 7.x
* Ubuntu 18.x, 19.x, 20.x, 21.x, 22.x, 

Please note this this project is still under development, and later versions of the above OS also might work. 

For any issues or requests, please  <a href="https://github.com/virtualmin/virtualmin-nginx/issues">Report Bug</a> or <a href="https://github.com/virtualmin/virtualmin-nginx/issues">Request Feature</a>

### Prerequisites

To use, you must have Webmin and Virtualmin installed. 
* Installing WebMin: https://webmin.com/download/
* Installing Virtualmin: https://www.virtualmin.com/download/

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


<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

