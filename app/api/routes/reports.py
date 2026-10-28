from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.reports import AdvancedReportResponse, ReportType
from app.services.export_service import ExportService
from app.services.reports_service import ReportsService

router = APIRouter(prefix="/reports", tags=["Advanced Expense Reports"])


@router.get(
    "",
    response_model=AdvancedReportResponse,
    summary="Retrieve Advanced Financial Report"
)
def get_advanced_report(
    report_type: ReportType = Query(ReportType.MONTHLY, description="Report type: daily, weekly, monthly, yearly, custom, category"),
    start_date: Optional[date] = Query(None, description="Start date filter (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date filter (YYYY-MM-DD)"),
    year: Optional[int] = Query(None, ge=2020, le=2100, description="Target year"),
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    category: Optional[str] = Query(None, description="Category filter (optional)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> AdvancedReportResponse:
    """
    Computes aggregated expense reports, category shares, recurring vs regular spending,
    and period comparison metrics strictly for the authenticated user.
    """
    return ReportsService.generate_report(
        db=db,
        user_id=current_user.id,
        report_type=report_type,
        start_date=start_date,
        end_date=end_date,
        year=year,
        month=month,
        category=category
    )


@router.get(
    "/export/csv",
    summary="Download Expense Report as CSV"
)
def export_report_csv(
    report_type: ReportType = Query(ReportType.MONTHLY, description="Report type: daily, weekly, monthly, yearly, custom, category"),
    start_date: Optional[date] = Query(None, description="Start date filter (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date filter (YYYY-MM-DD)"),
    year: Optional[int] = Query(None, ge=2020, le=2100, description="Target year"),
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    category: Optional[str] = Query(None, description="Category filter (optional)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Response:
    """
    Exports filtered expenses and category summaries to a CSV spreadsheet.
    Includes formula injection protection and UTF-8 BOM encoding.
    """
    report = ReportsService.generate_report(
        db=db,
        user_id=current_user.id,
        report_type=report_type,
        start_date=start_date,
        end_date=end_date,
        year=year,
        month=month,
        category=category
    )

    expenses = ReportsService.get_filtered_expenses(
        db=db,
        user_id=current_user.id,
        start_date=report.start_date,
        end_date=report.end_date,
        category=category
    )

    csv_bytes = ExportService.generate_csv(report, expenses)
    filename = f"kharcha_report_{report.start_date}_{report.end_date}.csv"

    return Response(
        content=csv_bytes,
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )


@router.get(
    "/export/pdf",
    summary="Download Expense Report as PDF"
)
def export_report_pdf(
    report_type: ReportType = Query(ReportType.MONTHLY, description="Report type: daily, weekly, monthly, yearly, custom, category"),
    start_date: Optional[date] = Query(None, description="Start date filter (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date filter (YYYY-MM-DD)"),
    year: Optional[int] = Query(None, ge=2020, le=2100, description="Target year"),
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    category: Optional[str] = Query(None, description="Category filter (optional)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Response:
    """
    Exports a publication-ready PDF financial report complete with KPI cards,
    recurring vs regular comparison, category distribution, and expense records.
    """
    report = ReportsService.generate_report(
        db=db,
        user_id=current_user.id,
        report_type=report_type,
        start_date=start_date,
        end_date=end_date,
        year=year,
        month=month,
        category=category
    )

    expenses = ReportsService.get_filtered_expenses(
        db=db,
        user_id=current_user.id,
        start_date=report.start_date,
        end_date=report.end_date,
        category=category
    )

    pdf_bytes = ExportService.generate_pdf(report, expenses)
    filename = f"kharcha_report_{report.start_date}_{report.end_date}.pdf"

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )
