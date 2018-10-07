# win-hole

This is a Windows DNS implementation of the pi-hole project. The original pi-hole project can be found here:

https://github.com/pi-hole/pi-hole

win-hole uses PowerShell scripts to configure a Windows Server 2016, or newer, DNS server for public Internet name resolution. DNS policies are created to block (i.e. black hole) DNS requests to known ad and malware servers. The default block list is aggregated from the same default lists used to create the adlist.list in the pi-hole project.

https://github.com/pi-hole/pi-hole/wiki/Customising-sources-for-ad-lists

win-hole is not a Microsoft open-source project. The win-hole project is a privately created, maintained, and supported open-source project. The Microsoft Corporation does not endorse, warranty, support, administrate, maintain, or is in any way directly involved in this project.

Support for win-hole is provided solely through the win-hole project site, by win-hole contributors and maintainers.

https://github.com/win-hole/win-hole
