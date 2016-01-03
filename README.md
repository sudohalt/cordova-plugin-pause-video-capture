# Cordova Plugin Pause Video Capture
Plugin for cordova for custom video recorder that has pause/resume feature.  

I created this plugin because there was no plugin I was aware of that offered the ability to pause videos while recording and then resume.  

# Install
<code>codova plugin install https://github.com/sudohalt/cordova-plugin-pause-video-capture</code>

Or

<code>ionic plugin install https://github.com/sudohalt/cordova-plugin-pause-video-capture</code>

# Usage

<code>
options = {duration:180, decrement:true};

navigator.device.pauseVideoCapture(options, 
  function(success) {console.log("success");}, 
  function(error) {console.log("error");}
);
</code>
