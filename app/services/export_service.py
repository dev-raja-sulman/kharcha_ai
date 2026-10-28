import codecs
import csv
import io
from datetime import datetime, timezone
from decimal import Decimal
from typing import List

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    HRFlowable,
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from app.models.expense import Expense
from app.schemas.reports import AdvancedReportResponse


class NumberedCanvas(canvas.Canvas):
    """
    Two-pass canvas to dynamically compute and print 'Page X of Y' footers.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_footer(num_pages)
            super().showPage()
        super().save()

    def draw_footer(self, page_count: int):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        # Top line
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.5)
        self.line(36, 40, letter[0] - 36, 40)

        # Footer text
        footer_text = "KharchaAI Personal Financial Management • Automated Financial Report • Confidential"
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawString(36, 26, footer_text)
        self.drawRightString(letter[0] - 36, 26, page_str)
        self.restoreState()


class ExportService:
    """
    Export Service for CSV and PDF financial reports in KharchaAI.
    Ensures safe formatting, injection prevention, and publication-ready PDF documents.
    """

    @staticmethod
    def sanitize_csv_field(value: str) -> str:
        """
        Guards against spreadsheet formula injection (CSV Injection / CWE-1236).
        Prepends a single quote if string begins with unsafe characters: =, +, -, @, tab, or carriage return.
        """
        if not value:
            return ""
        s = str(value)
        if s[0] in ("=", "+", "-", "@", "\t", "\r"):
            return f"'{s}"
        return s

    @classmethod
    def generate_csv(
        cls,
        report: AdvancedReportResponse,
        expenses: List[Expense]
    ) -> bytes:
        """
        Generates UTF-8 encoded CSV with BOM for high-compatibility spreadsheet imports.
        Contains report summaries and transaction records.
        """
        output = io.StringIO()
        writer = csv.writer(output, quoting=csv.QUOTE_MINIMAL)

        # Header summary
        writer.writerow(["KharchaAI Financial Report"])
        writer.writerow(["Report Type", cls.sanitize_csv_field(report.report_type.title())])
        writer.writerow(["Period", f"{report.start_date} to {report.end_date}"])
        writer.writerow(["Generated At", cls.sanitize_csv_field(report.generated_at)])
        writer.writerow(["Total Expenditure (PKR)", f"{report.total_expenditure:,.2f}"])
        writer.writerow(["Total Transactions", report.total_expenses])
        writer.writerow(["Average Daily Spend (PKR)", f"{report.average_daily_spending:,.2f}"])
        writer.writerow([
            "Recurring vs Regular",
            f"Recurring: PKR {report.recurring_vs_regular.recurring_amount:,.2f} ({report.recurring_vs_regular.recurring_percentage}%) | "
            f"Regular: PKR {report.recurring_vs_regular.regular_amount:,.2f} ({report.recurring_vs_regular.regular_percentage}%)"
        ])
        writer.writerow([])

        # Category summary
        writer.writerow(["--- CATEGORY SUMMARY ---"])
        writer.writerow(["Category", "Total Spent (PKR)", "Share (%)", "Transactions"])
        for cat in report.category_breakdown:
            writer.writerow([
                cls.sanitize_csv_field(cat.category),
                f"{cat.total_amount:,.2f}",
                f"{cat.percentage:.2f}%",
                cat.count
            ])
        writer.writerow([])

        # Transactions
        writer.writerow(["--- EXPENSE TRANSACTIONS ---"])
        writer.writerow(["Date", "Title", "Category", "Amount (PKR)", "Payment Method", "Type", "Notes"])
        for exp in expenses:
            expense_type = "Recurring" if exp.recurring_rule_id is not None else "Regular"
            writer.writerow([
                exp.expense_date.isoformat(),
                cls.sanitize_csv_field(exp.title),
                cls.sanitize_csv_field(exp.category),
                f"{Decimal(str(exp.amount)):,.2f}",
                cls.sanitize_csv_field(exp.payment_method),
                expense_type,
                cls.sanitize_csv_field(exp.description or "")
            ])

        # Prepend UTF-8 BOM for MS Excel compatibility
        csv_text = output.getvalue()
        return codecs.BOM_UTF8 + csv_text.encode("utf-8")

    @classmethod
    def generate_pdf(
        cls,
        report: AdvancedReportResponse,
        expenses: List[Expense]
    ) -> bytes:
        """
        Generates a readable, styled PDF expense report using ReportLab.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=36,
            leftMargin=36,
            topMargin=36,
            bottomMargin=54
        )

        styles = getSampleStyleSheet()

        # Custom Brand Styles
        title_style = ParagraphStyle(
            "ReportTitle",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=20,
            leading=24,
            textColor=colors.HexColor("#0F766E")
        )
        subtitle_style = ParagraphStyle(
            "ReportSubtitle",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=10,
            leading=14,
            textColor=colors.HexColor("#64748B")
        )
        section_heading = ParagraphStyle(
            "SectionHeading",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=12,
            leading=16,
            textColor=colors.HexColor("#0F172A"),
            spaceBefore=12,
            spaceAfter=6
        )
        body_style = ParagraphStyle(
            "ReportBody",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=9,
            leading=12,
            textColor=colors.HexColor("#0F172A")
        )
        body_bold = ParagraphStyle(
            "ReportBodyBold",
            parent=body_style,
            fontName="Helvetica-Bold"
        )
        body_muted = ParagraphStyle(
            "ReportBodyMuted",
            parent=body_style,
            textColor=colors.HexColor("#64748B")
        )

        story = []

        # 1. Header Banner
        header_data = [
            [
                Paragraph("<b>KharchaAI</b> — Expense Report", title_style),
                Paragraph(
                    f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}<br/>"
                    f"Period: <b>{report.start_date}</b> to <b>{report.end_date}</b>",
                    subtitle_style
                )
            ]
        ]
        header_table = Table(header_data, colWidths=[3.5 * inch, 4.0 * inch])
        header_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
        ]))
        story.append(header_table)
        story.append(Spacer(1, 10))
        story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#0F766E"), spaceAfter=14))

        # 2. Key Metrics Summary Grid (4 Cards in a Table)
        top_cat_name = report.highest_spending_category.category if report.highest_spending_category else "None"
        top_cat_amt = f"PKR {report.highest_spending_category.total_amount:,.2f}" if report.highest_spending_category else "PKR 0.00"

        kpi_data = [
            [
                Paragraph("<b>Total Expenditure</b>", body_muted),
                Paragraph("<b>Transactions</b>", body_muted),
                Paragraph("<b>Daily Average</b>", body_muted),
                Paragraph("<b>Top Category</b>", body_muted),
            ],
            [
                Paragraph(f"<font size=13 color='#0F766E'><b>PKR {report.total_expenditure:,.2f}</b></font>", body_style),
                Paragraph(f"<font size=13 color='#0F172A'><b>{report.total_expenses}</b></font>", body_style),
                Paragraph(f"<font size=13 color='#0F172A'><b>PKR {report.average_daily_spending:,.2f}</b></font>", body_style),
                Paragraph(f"<font size=11 color='#0F172A'><b>{top_cat_name}</b></font><br/><font size=8 color='#64748B'>{top_cat_amt}</font>", body_style),
            ]
        ]
        kpi_table = Table(kpi_data, colWidths=[1.87 * inch] * 4)
        kpi_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F0FDFA")),
            ('BOX', (0, 0), (-1, -1), 1, colors.HexColor("#99F6E4")),
            ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#CCFBF1")),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('LEFTPADDING', (0, 0), (-1, -1), 10),
            ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ]))
        story.append(kpi_table)
        story.append(Spacer(1, 14))

        # 3. Recurring vs Regular & Period Comparison Tables (2 Columns side-by-side)
        rec_data = report.recurring_vs_regular
        comp = report.period_comparison

        trend_color = "#10B981" if comp and comp.trend == "decreased" else ("#EF4444" if comp and comp.trend == "increased" else "#64748B")
        comp_summary = "No previous period data"
        if comp and comp.trend != "no_previous_data":
            sign = "+" if comp.difference > 0 else ""
            comp_summary = f"{comp.trend.title()} by {sign}PKR {abs(comp.difference):,.2f} ({comp.percentage_change:+.1f}%)"

        prev_spent_val = Decimal(str(comp.previous_expenditure)) if comp else Decimal("0.00")
        prev_start_str = str(comp.previous_start_date) if comp else "-"
        prev_end_str = str(comp.previous_end_date) if comp else "-"

        side_by_side_data = [
            [
                Paragraph("<b>Recurring vs Regular Spending</b>", section_heading),
                Paragraph("<b>Period Comparison</b>", section_heading)
            ],
            [
                Paragraph(
                    f"&bull; <b>Recurring:</b> PKR {rec_data.recurring_amount:,.2f} ({rec_data.recurring_percentage}%, {rec_data.recurring_count} txs)<br/>"
                    f"&bull; <b>Regular / One-Off:</b> PKR {rec_data.regular_amount:,.2f} ({rec_data.regular_percentage}%, {rec_data.regular_count} txs)",
                    body_style
                ),
                Paragraph(
                    f"&bull; <b>Previous Period:</b> {prev_start_str} to {prev_end_str}<br/>"
                    f"&bull; <b>Previous Spend:</b> PKR {prev_spent_val:,.2f}<br/>"
                    f"&bull; <b>Status:</b> <font color='{trend_color}'><b>{comp_summary}</b></font>",
                    body_style
                )
            ]
        ]
        side_table = Table(side_by_side_data, colWidths=[3.75 * inch, 3.75 * inch])
        side_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 1), (0, 1), colors.HexColor("#F8FAFC")),
            ('BACKGROUND', (1, 1), (1, 1), colors.HexColor("#F8FAFC")),
            ('BOX', (0, 1), (0, 1), 0.5, colors.HexColor("#E2E8F0")),
            ('BOX', (1, 1), (1, 1), 0.5, colors.HexColor("#E2E8F0")),
            ('PADDING', (0, 1), (-1, 1), 8),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ]))
        story.append(side_table)
        story.append(Spacer(1, 14))

        # 4. Category Breakdown Table
        story.append(Paragraph("Category Spending Breakdown", section_heading))
        cat_table_data = [
            [
                Paragraph("<b>Category</b>", body_bold),
                Paragraph("<b>Expenditure (PKR)</b>", body_bold),
                Paragraph("<b>Share (%)</b>", body_bold),
                Paragraph("<b>Count</b>", body_bold)
            ]
        ]
        if not report.category_breakdown:
            cat_table_data.append([
                Paragraph("No expense records in this period.", body_muted),
                Paragraph("PKR 0.00", body_style),
                Paragraph("0.0%", body_style),
                Paragraph("0", body_style)
            ])
        else:
            for cat in report.category_breakdown:
                cat_table_data.append([
                    Paragraph(cat.category, body_style),
                    Paragraph(f"PKR {cat.total_amount:,.2f}", body_style),
                    Paragraph(f"{cat.percentage:.1f}%", body_style),
                    Paragraph(str(cat.count), body_style),
                ])

        cat_table = Table(cat_table_data, colWidths=[2.5 * inch, 2.0 * inch, 1.5 * inch, 1.5 * inch])
        cat_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#F1F5F9")),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
            ('ALIGN', (1, 0), (-1, -1), 'LEFT'),
        ]))
        story.append(cat_table)
        story.append(Spacer(1, 14))

        # 5. Detailed Transactions Table
        story.append(Paragraph(f"Expense Records ({len(expenses)} Transactions)", section_heading))
        exp_table_data = [
            [
                Paragraph("<b>Date</b>", body_bold),
                Paragraph("<b>Title</b>", body_bold),
                Paragraph("<b>Category</b>", body_bold),
                Paragraph("<b>Amount (PKR)</b>", body_bold),
                Paragraph("<b>Method</b>", body_bold),
                Paragraph("<b>Type</b>", body_bold),
            ]
        ]
        if not expenses:
            exp_table_data.append([
                Paragraph("—", body_muted),
                Paragraph("No expenses recorded for this timeframe.", body_muted),
                Paragraph("—", body_muted),
                Paragraph("PKR 0.00", body_muted),
                Paragraph("—", body_muted),
                Paragraph("—", body_muted),
            ])
        else:
            # Display up to 150 items in PDF to prevent unbounded file size
            display_expenses = expenses[:150]
            for exp in display_expenses:
                is_recurring = "Recurring" if exp.recurring_rule_id is not None else "Regular"
                exp_table_data.append([
                    Paragraph(exp.expense_date.strftime("%Y-%m-%d"), body_style),
                    Paragraph(exp.title[:35], body_style),
                    Paragraph(exp.category, body_style),
                    Paragraph(f"PKR {Decimal(str(exp.amount)):,.2f}", body_style),
                    Paragraph(exp.payment_method, body_style),
                    Paragraph(is_recurring, body_style),
                ])
            if len(expenses) > 150:
                exp_table_data.append([
                    Paragraph("...", body_muted),
                    Paragraph(f"<i>... and {len(expenses) - 150} more records (export CSV for full dataset)</i>", body_muted),
                    Paragraph("", body_muted),
                    Paragraph("", body_muted),
                    Paragraph("", body_muted),
                    Paragraph("", body_muted),
                ])

        exp_table = Table(
            exp_table_data,
            colWidths=[1.1 * inch, 2.2 * inch, 1.2 * inch, 1.3 * inch, 1.0 * inch, 0.7 * inch]
        )
        exp_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#F1F5F9")),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ]))
        story.append(exp_table)

        doc.build(story, canvasmaker=NumberedCanvas)
        return buffer.getvalue()
