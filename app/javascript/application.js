// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import LocalTime from "local-time"
import "controllers"

// Initialize LocalTime for timezone conversion
try {
  LocalTime.start()
  console.log("LocalTime initialized")
} catch (error) {
  console.error("LocalTime initialization error:", error)
}

// Function to run LocalTime conversion
const runLocalTime = () => {
  try {
    if (LocalTime && LocalTime.run) {
      LocalTime.run()
      console.log("LocalTime.run() executed")
    }
  } catch (error) {
    console.error("LocalTime.run() error:", error)
  }
}

// Re-run LocalTime after Turbo navigations to convert new time elements
document.addEventListener("turbo:load", runLocalTime)
document.addEventListener("turbo:frame-load", runLocalTime)
document.addEventListener("turbo:morph", runLocalTime)

// Also run on DOMContentLoaded as fallback
if (document.readyState === 'loading') {
  document.addEventListener("DOMContentLoaded", runLocalTime)
} else {
  // DOM already loaded, run immediately
  runLocalTime()
}
document.addEventListener("turbo:frame-load", runLocalTime)
document.addEventListener("turbo:morph", runLocalTime)

// Also run on DOMContentLoaded as fallback
if (document.readyState === 'loading') {
  document.addEventListener("DOMContentLoaded", runLocalTime)
} else {
  // DOM already loaded, run immediately
  runLocalTime()
}
