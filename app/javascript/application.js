// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import LocalTime from "local-time"
import "controllers"

// Register service worker for PWA and push notifications
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/service-worker.js')
    .then(registration => {
      console.log('Service Worker registered:', registration.scope)
    })
    .catch(error => {
      console.error('Service Worker registration failed:', error)
    })
}

// Initialize LocalTime for timezone conversion
try {
  LocalTime.start()
} catch (error) {
  console.error("LocalTime initialization error:", error)
}

// Function to run LocalTime conversion
const runLocalTime = () => {
  try {
    if (LocalTime && LocalTime.run) {
      LocalTime.run()
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
