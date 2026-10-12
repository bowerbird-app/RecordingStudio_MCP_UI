import { Controller } from "@hotwired/stimulus"
import { flatPackCopy } from "demo/copy"

export default class extends Controller {
  label(name) {
    const title = `Item ${name}`
    return flatPackCopy("%{title}", { title })
  }
}
