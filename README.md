##RetroTransfer

RetroTransfer is an HTTP Server application running on Apple platforms.

##Use Case

When you have an old phone (such as Nokia N95) that cannot download directly from the internet, and you don't have a USB cable. You download other HTTP Server apps from the App Store, but they fail to connect properly.

##Current Status

The application is currently in its initial version. Future updates may include support for more transfer methods. Like Symbian S60 v3, Symbian S60 V5, Java Jar

##Todo:

- [ ] Support for macOS
- [ ] Design dedicated versions of the app for various platforms, enabling direct file transfer via WiFi


##Testing Results
Currently only tested successfully on Nokia N95 8G, with the following browsers:

|  APP   | 兼容性 | 备注 |
| :-----: | :------: | :------: | 
| UC Browser 8.6 (sis) |    ⚠️     |    can only download non-sis, non-sisx, non-jar files     |
|  UC Browser 8.9 (sis)   |    ✅     |    requires disabling download security check     |
|  System default browser   |    ✅     |    can download any file     |
|  UC Browser 9.0 (java)   |    ✅     |    can download any file     |
|  Opera 7.6 (sis)   |    ❌     |    Unable to test, Opera on the test phone couldn't open any webpages     |

