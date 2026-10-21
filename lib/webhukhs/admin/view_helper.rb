# frozen_string_literal: true

module Webhukhs
  module Admin
    # Table-building helpers for the admin views.
    module ViewHelper
      # Renders a table inside a scroll container. Cells are `white-space: nowrap`, so one long
      # column would otherwise take the whole page sideways with it.
      #
      # @param columns [Array<String>] header cell contents
      # @param records [Array] rows to render
      # @yieldparam record [Object] one of the records
      # @yieldreturn [Array] cell contents for that record
      # @return [ActiveSupport::SafeBuffer]
      def admin_table(columns, records)
        rows = records.map do |record|
          tag.tr { safe_join(yield(record).map { |cell| tag.td(cell) }) }
        end
        rows = [tag.tr(tag.td("No records.", colspan: columns.length, class: "empty"))] if rows.empty?

        thead = tag.thead(tag.tr(safe_join(columns.map { |column| tag.th(column) })))
        tag.div(tag.table(safe_join([thead, tag.tbody(safe_join(rows))]), class: "admin-table"), class: "table-scroll")
      end

      # Column header linking to the index sorted by that column. Clicking the active column
      # flips the direction, any other column starts out descending.
      #
      # @param label [String] header text
      # @param column [String] column to sort by
      # @param sort [String] currently sorted column
      # @param direction [String] current direction, "asc" or "desc"
      # @return [ActiveSupport::SafeBuffer]
      def sort_link(label, column, sort:, direction:)
        active = column == sort
        next_direction = (active && direction == "desc") ? "asc" : "desc"
        query = request.query_parameters.except("page").merge("sort" => column, "direction" => next_direction)
        label = safe_join([label, tag.span((direction == "asc") ? "▲" : "▼", class: "sort-arrow")], " ") if active
        link_to(label, query, class: "sort-link")
      end

      # Button copying a value to the clipboard (see admin.js).
      #
      # @param value [String] text to copy
      # @return [ActiveSupport::SafeBuffer]
      def copy_button(value)
        tag.button(class: "btn-copy", type: "button", title: "Copy to clipboard", data: {copy: value})
      end
    end
  end
end
