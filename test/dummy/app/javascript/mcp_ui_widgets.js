import { Application } from "@hotwired/stimulus"
import AccordionController from "flat_pack/controllers/accordion_controller"
import ChipController from "flat_pack/controllers/chip_controller"
import CollectionEditorController from "flat_pack/controllers/collection_editor_controller"
import ComboboxController from "flat_pack/controllers/combobox_controller"
import DateInputController from "flat_pack/controllers/date_input_controller"
import DrawerController from "flat_pack/controllers/drawer_controller"
import ListOrderableController from "flat_pack/controllers/list_orderable_controller"
import ModalController from "flat_pack/controllers/modal_controller"
import PickerController from "flat_pack/controllers/picker_controller"
import TableSortableController from "flat_pack/controllers/table_sortable_controller"
import TabsController from "flat_pack/controllers/tabs_controller"

const application = Application.start()

application.register("flat-pack--accordion", AccordionController)
application.register("flat-pack--chip", ChipController)
application.register("flat-pack--collection-editor", CollectionEditorController)
application.register("flat-pack--combobox", ComboboxController)
application.register("flat-pack--date-input", DateInputController)
application.register("flat-pack--drawer", DrawerController)
application.register("flat-pack--list-orderable", ListOrderableController)
application.register("flat-pack--modal", ModalController)
application.register("flat-pack--picker", PickerController)
application.register("flat-pack--table-sortable", TableSortableController)
application.register("flat-pack--tabs", TabsController)

window.Stimulus = application
