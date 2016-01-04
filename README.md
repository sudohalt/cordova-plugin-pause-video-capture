# Cordova Plugin Pause Video Capture
Plugin for cordova for custom video recorder that has pause/resume feature.  

I created this plugin because there was no plugin I was aware of that offered the ability to pause videos while recording and then resume.  Currently this plugin only works for iOS, and I am currently looking into supporting other platforms.

# Install
<code>codova plugin install https://github.com/sudohalt/cordova-plugin-pause-video-capture</code>

Or

<code>ionic plugin install https://github.com/sudohalt/cordova-plugin-pause-video-capture</code>

# Usage
The plugin creates a global variable called <code>window.pauseVideoCapture</code> which contains the functions for this plugin.  There is only one function called <code>pauseVideoCapture</code>, which opens up your camera and allows you to take videos, replay videos, and retake videos.

```javascript
options = {duration:180, decrement:true};
window.pauseVideoCapture.pauseVideoCapture(options,
  function(videoData) {
    console.log("success");
    $scope.videoData = videoData;
  },
  function(error) {
    console.log("error");
    console.log(error);
    $scope.videoData = null;
  }
);
```
