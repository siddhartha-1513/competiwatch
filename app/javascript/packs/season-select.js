import {on} from 'delegated-events'

on('change', '.js-season-select', function(event) {
  const select = event.target
  const season = select.value
  const urlTemplate = select.getAttribute('data-url-template')
  const url = urlTemplate.replace(/{season}/, season)
  select.disabled = true
  window.location.href = url
})