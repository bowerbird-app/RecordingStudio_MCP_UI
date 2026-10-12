export class Controller {}

export class Application {
  static start(element) {
    const application = new Application()
    application.element = element
    application.registered = {}
    return application
  }

  register(identifier, constructor) {
    this.registered[identifier] = constructor
  }
}
