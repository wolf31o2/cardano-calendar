import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 'view', 'offcanvasBody' ]

  initialize() {
    console.log("FOOO")
  }

  updateSubscribeLink(event) {
    const linkElement = event.currentTarget
    const currentUrl = new URL(document.location)
    const currentSearchParams = currentUrl.searchParams
    const linkUrl = new URL(linkElement.href)

    // Not required, but removing start_date from params
    currentSearchParams.delete('start_date')

    // The link uses webcal protocol.
    // It seems weird but `linkUrl.origin` is null and pathname contains the url
    const newUrl = linkUrl.protocol + linkUrl.pathname + currentUrl.search

    linkElement.setAttribute('href', newUrl)
  }

  offcanvasBodyTargetConnected(element) {
    const viewLinks = [...element.querySelectorAll('a.event_view')]
    const filterToggle = [...element.querySelectorAll('.event_filter input')]

    document.documentElement.addEventListener("turbo:visit", event => {
      setTimeout(() => {
        viewLinks.forEach(link => link.classList.add('disabled'))
        filterToggle.forEach(toggle => toggle.setAttribute('disabled', ''))
      }, "100")
    })

    'turbo:render turbo:before-stream-render'.split(' ').forEach(eventStr => {
      document.documentElement.addEventListener(eventStr, event => {
        setTimeout(() => {
          viewLinks.forEach(link => link.classList.remove('disabled'))
          filterToggle.forEach(toggle => toggle.removeAttribute('disabled'))
        }, "100")
      })
    })
  }

  viewTargetConnected(element) {
    const defaultClasses = element.querySelector("a:not(.active)").className
    const activeClasses = element.querySelector("a.active").className
    const viewLinks = [...element.children]

    viewLinks.forEach(link => {
      link.addEventListener('click', event => {
        viewLinks.forEach(l => l.setAttribute("class", defaultClasses))
        event.currentTarget.setAttribute("class", activeClasses)


        const currentUrl = new URL(document.location)
        currentUrl.pathname = event.currentTarget.dataset["view"]

        event.preventDefault()
        Turbo.visit(currentUrl)
      })
    })
  }

  toggleFilter(event) {
    const switchInput = event.currentTarget
    const currentUrl = new URL(document.location)
    const currentParams = currentUrl.searchParams
    const filterParam = switchInput.dataset["filterParam"]
    const defaultValue = switchInput.dataset["filterDefault"]

    currentParams.delete("filter["+filterParam+"]")

    if(switchInput.checked) {
      if(defaultValue == "off") currentParams.set("filter["+filterParam+"]", "on")
    }
    else {
      if(defaultValue == "on") currentParams.set("filter["+filterParam+"]", "off")
    }

    Turbo.visit(currentUrl, { action: "restore" })
  }
}