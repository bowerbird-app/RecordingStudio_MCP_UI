export function flatPackCopy(template, vars) {
  return String(template ?? "").replace(/%\{(\w+)\}/g, (_, name) => {
    const value = vars[name]
    return value == null ? "" : String(value)
  })
}
