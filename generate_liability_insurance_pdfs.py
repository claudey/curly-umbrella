#!/usr/bin/env python3
"""
Generate Liability Insurance sample PDF documents for testing
All content is fictional and for testing purposes only
"""

from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
import os
from datetime import datetime, timedelta

def create_business_registration(filename, business_data):
    """Create a business registration certificate"""
    c = canvas.Canvas(filename, pagesize=letter)
    width, height = letter
    
    # Header
    c.setFont("Helvetica-Bold", 16)
    c.drawString(50, height - 50, "STATE DEPARTMENT OF COMMERCE")
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, height - 80, "CERTIFICATE OF BUSINESS REGISTRATION")
    
    # Registration number and dates
    c.setFont("Helvetica", 10)
    c.drawString(width - 250, height - 50, f"Registration No: {business_data['registration_number']}")
    c.drawString(width - 250, height - 70, f"Issue Date: {business_data['issue_date']}")
    c.drawString(width - 250, height - 90, f"Expiration: {business_data['expiration_date']}")
    
    # Business information
    y_pos = height - 140
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "BUSINESS INFORMATION")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    business_details = [
        ("Business Name:", business_data['business_name']),
        ("DBA Name:", business_data['dba_name']),
        ("Business Type:", business_data['business_type']),
        ("Industry:", business_data['industry']),
        ("Federal EIN:", business_data['federal_ein']),
        ("State Tax ID:", business_data['state_tax_id'])
    ]
    
    for label, value in business_details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Business address
    y_pos -= 20
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "BUSINESS ADDRESS")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    address_details = [
        ("Street Address:", business_data['street_address']),
        ("City, State, ZIP:", f"{business_data['city']}, {business_data['state']} {business_data['zip_code']}"),
        ("Phone:", business_data['phone']),
        ("Email:", business_data['email'])
    ]
    
    for label, value in address_details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Owner/Officer information
    y_pos -= 20
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "OWNER/OFFICER INFORMATION")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    owner_details = [
        ("Principal Owner:", business_data['principal_owner']),
        ("Title:", business_data['owner_title']),
        ("Ownership %:", business_data['ownership_percentage']),
        ("Owner Address:", business_data['owner_address'])
    ]
    
    for label, value in owner_details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Authorized activities
    y_pos -= 20
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "AUTHORIZED BUSINESS ACTIVITIES")
    
    y_pos -= 25
    c.setFont("Helvetica", 10)
    activities = business_data.get('activities', [])
    for activity in activities:
        c.drawString(70, y_pos, f"• {activity}")
        y_pos -= 20
    
    # Footer
    c.setFont("Helvetica", 8)
    c.drawString(50, 80, "This certificate is valid only for the business activities listed above.")
    c.drawString(50, 65, "Any changes to business information must be reported within 30 days.")
    c.drawString(50, 50, "This is a sample document for testing purposes only")
    c.drawString(50, 35, "All information contained herein is fictional")
    
    c.save()

def create_financial_statement(filename, financial_data):
    """Create a financial statement document"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("FINANCIAL STATEMENT", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Company info
    company_info = [
        ['Company Name:', financial_data['company_name']],
        ['Statement Period:', f"{financial_data['period_start']} to {financial_data['period_end']}"],
        ['Statement Date:', financial_data['statement_date']],
        ['Prepared By:', financial_data['prepared_by']],
        ['CPA Firm:', financial_data['cpa_firm']]
    ]
    
    info_table = Table(company_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Balance Sheet
    balance_title = Paragraph("BALANCE SHEET", styles['Heading2'])
    story.append(balance_title)
    
    # Assets
    assets_title = Paragraph("ASSETS", styles['Heading3'])
    story.append(assets_title)
    
    assets_data = [
        ['Current Assets', '', ''],
        ['Cash and Cash Equivalents', '', f"${financial_data['cash']:,}"],
        ['Accounts Receivable', '', f"${financial_data['accounts_receivable']:,}"],
        ['Inventory', '', f"${financial_data['inventory']:,}"],
        ['Prepaid Expenses', '', f"${financial_data['prepaid_expenses']:,}"],
        ['Total Current Assets', '', f"${financial_data['total_current_assets']:,}"],
        ['', '', ''],
        ['Fixed Assets', '', ''],
        ['Property, Plant & Equipment', '', f"${financial_data['ppe']:,}"],
        ['Less: Accumulated Depreciation', '', f"(${financial_data['accumulated_depreciation']:,})"],
        ['Net Fixed Assets', '', f"${financial_data['net_fixed_assets']:,}"],
        ['', '', ''],
        ['TOTAL ASSETS', '', f"${financial_data['total_assets']:,}"]
    ]
    
    assets_table = Table(assets_data, colWidths=[2.5*inch, 1*inch, 2.5*inch])
    assets_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (2, 0), (2, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 7), (0, 7), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LINEABOVE', (0, -1), (-1, -1), 1, colors.black),
        ('LINEBELOW', (0, -1), (-1, -1), 2, colors.black)
    ]))
    story.append(assets_table)
    story.append(Spacer(1, 20))
    
    # Liabilities and Equity
    liabilities_title = Paragraph("LIABILITIES AND EQUITY", styles['Heading3'])
    story.append(liabilities_title)
    
    liabilities_data = [
        ['Current Liabilities', '', ''],
        ['Accounts Payable', '', f"${financial_data['accounts_payable']:,}"],
        ['Accrued Expenses', '', f"${financial_data['accrued_expenses']:,}"],
        ['Short-term Debt', '', f"${financial_data['short_term_debt']:,}"],
        ['Total Current Liabilities', '', f"${financial_data['total_current_liabilities']:,}"],
        ['', '', ''],
        ['Long-term Debt', '', f"${financial_data['long_term_debt']:,}"],
        ['Total Liabilities', '', f"${financial_data['total_liabilities']:,}"],
        ['', '', ''],
        ['Shareholders\' Equity', '', ''],
        ['Common Stock', '', f"${financial_data['common_stock']:,}"],
        ['Retained Earnings', '', f"${financial_data['retained_earnings']:,}"],
        ['Total Shareholders\' Equity', '', f"${financial_data['total_equity']:,}"],
        ['', '', ''],
        ['TOTAL LIABILITIES & EQUITY', '', f"${financial_data['total_liab_equity']:,}"]
    ]
    
    liabilities_table = Table(liabilities_data, colWidths=[2.5*inch, 1*inch, 2.5*inch])
    liabilities_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (2, 0), (2, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 7), (0, 7), 'Helvetica-Bold'),
        ('FONTNAME', (0, 9), (0, 9), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LINEABOVE', (0, -1), (-1, -1), 1, colors.black),
        ('LINEBELOW', (0, -1), (-1, -1), 2, colors.black)
    ]))
    story.append(liabilities_table)
    story.append(Spacer(1, 30))
    
    # Income Statement
    income_title = Paragraph("INCOME STATEMENT", styles['Heading2'])
    story.append(income_title)
    
    income_data = [
        ['Revenue', '', f"${financial_data['revenue']:,}"],
        ['Cost of Goods Sold', '', f"${financial_data['cogs']:,}"],
        ['Gross Profit', '', f"${financial_data['gross_profit']:,}"],
        ['', '', ''],
        ['Operating Expenses', '', ''],
        ['Salaries and Benefits', '', f"${financial_data['salaries']:,}"],
        ['Rent and Utilities', '', f"${financial_data['rent_utilities']:,}"],
        ['Marketing and Advertising', '', f"${financial_data['marketing']:,}"],
        ['Professional Services', '', f"${financial_data['professional_services']:,}"],
        ['Other Operating Expenses', '', f"${financial_data['other_expenses']:,}"],
        ['Total Operating Expenses', '', f"${financial_data['total_operating_expenses']:,}"],
        ['', '', ''],
        ['Operating Income', '', f"${financial_data['operating_income']:,}"],
        ['Interest Expense', '', f"${financial_data['interest_expense']:,}"],
        ['Net Income Before Taxes', '', f"${financial_data['income_before_taxes']:,}"],
        ['Income Tax Expense', '', f"${financial_data['tax_expense']:,}"],
        ['NET INCOME', '', f"${financial_data['net_income']:,}"]
    ]
    
    income_table = Table(income_data, colWidths=[2.5*inch, 1*inch, 2.5*inch])
    income_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (2, 0), (2, -1), 'RIGHT'),
        ('FONTNAME', (0, 4), (0, 4), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LINEABOVE', (0, -1), (-1, -1), 1, colors.black),
        ('LINEBELOW', (0, -1), (-1, -1), 2, colors.black)
    ]))
    story.append(income_table)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_liability_policy(filename, policy_data):
    """Create a liability insurance policy template"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("GENERAL LIABILITY INSURANCE POLICY", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Policy details
    policy_info = [
        ['Policy Number:', policy_data['policy_number']],
        ['Policy Period:', f"{policy_data['effective_date']} to {policy_data['expiration_date']}"],
        ['Insurance Company:', policy_data['insurance_company']],
        ['Producer/Agent:', policy_data['agent_name']],
        ['Issue Date:', policy_data['issue_date']]
    ]
    
    info_table = Table(policy_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Named insured
    insured_title = Paragraph("NAMED INSURED", styles['Heading2'])
    story.append(insured_title)
    
    insured_info = [
        ['Business Name:', policy_data['business_name']],
        ['Business Address:', policy_data['business_address']],
        ['Business Phone:', policy_data['business_phone']],
        ['Principal Contact:', policy_data['principal_contact']],
        ['Industry Classification:', policy_data['industry_classification']]
    ]
    
    insured_table = Table(insured_info, colWidths=[2*inch, 4*inch])
    insured_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(insured_table)
    story.append(Spacer(1, 20))
    
    # Coverage details
    coverage_title = Paragraph("COVERAGE DETAILS", styles['Heading2'])
    story.append(coverage_title)
    
    coverage_data = [
        ['Coverage', 'Each Occurrence', 'General Aggregate', 'Premium'],
        ['Bodily Injury & Property Damage', f"${policy_data['each_occurrence']:,}", f"${policy_data['general_aggregate']:,}", f"${policy_data['bd_pd_premium']:,}"],
        ['Personal & Advertising Injury', f"${policy_data['personal_injury_limit']:,}", 'Included in General Aggregate', f"${policy_data['personal_injury_premium']:,}"],
        ['Products-Completed Operations', f"${policy_data['products_ops_occurrence']:,}", f"${policy_data['products_ops_aggregate']:,}", f"${policy_data['products_ops_premium']:,}"],
        ['Medical Expenses', f"${policy_data['medical_expenses']:,}", 'N/A', f"${policy_data['medical_premium']:,}"],
        ['', '', 'Total Annual Premium:', f"${policy_data['total_premium']:,}"]
    ]
    
    coverage_table = Table(coverage_data, colWidths=[2.5*inch, 1.5*inch, 1.5*inch, 1*inch])
    coverage_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -2), 1, colors.black),
        ('LINEABOVE', (2, -1), (-1, -1), 2, colors.black)
    ]))
    story.append(coverage_table)
    story.append(Spacer(1, 20))
    
    # Deductibles
    deductible_title = Paragraph("DEDUCTIBLES", styles['Heading2'])
    story.append(deductible_title)
    
    deductible_text = f"""
    Per Occurrence Deductible: ${policy_data['deductible']:,}
    
    The deductible applies to each covered occurrence. The insured is responsible for the 
    deductible amount before coverage begins.
    """
    
    deductible_para = Paragraph(deductible_text, styles['Normal'])
    story.append(deductible_para)
    story.append(Spacer(1, 20))
    
    # Key exclusions
    exclusions_title = Paragraph("KEY EXCLUSIONS", styles['Heading2'])
    story.append(exclusions_title)
    
    exclusions_text = """
    This policy does not cover claims arising from:
    
    • Professional services (requires separate Professional Liability coverage)
    • Cyber/data breach incidents (requires separate Cyber Liability coverage)
    • Employment practices (requires separate Employment Practices Liability coverage)
    • Pollution incidents (requires separate Environmental coverage)
    • Aircraft, auto, or watercraft operations (require separate coverage)
    • Workers' compensation (requires separate coverage)
    • Intentional criminal acts
    
    This is a summary only. Please refer to the complete policy for all terms and conditions.
    """
    
    exclusions_para = Paragraph(exclusions_text, styles['Normal'])
    story.append(exclusions_para)
    story.append(Spacer(1, 20))
    
    # Claims reporting
    claims_title = Paragraph("CLAIMS REPORTING", styles['Heading2'])
    story.append(claims_title)
    
    claims_text = f"""
    Claims should be reported immediately to:
    
    Claims Department: {policy_data['claims_phone']}
    24-Hour Claims Hotline: {policy_data['claims_hotline']}
    Online Claims Reporting: {policy_data['claims_website']}
    
    Prompt reporting is essential for proper claims handling.
    """
    
    claims_para = Paragraph(claims_text, styles['Normal'])
    story.append(claims_para)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_contract_document(filename, contract_data):
    """Create a business contract document"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("SERVICE AGREEMENT CONTRACT", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Contract details
    contract_info = [
        ['Contract Number:', contract_data['contract_number']],
        ['Effective Date:', contract_data['effective_date']],
        ['Contract Term:', contract_data['contract_term']],
        ['Total Contract Value:', f"${contract_data['contract_value']:,}"]
    ]
    
    info_table = Table(contract_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Parties
    parties_title = Paragraph("CONTRACTING PARTIES", styles['Heading2'])
    story.append(parties_title)
    
    # Service provider
    provider_title = Paragraph("Service Provider:", styles['Heading3'])
    story.append(provider_title)
    
    provider_info = [
        ['Company Name:', contract_data['provider_name']],
        ['Address:', contract_data['provider_address']],
        ['Contact Person:', contract_data['provider_contact']],
        ['Phone:', contract_data['provider_phone']],
        ['Email:', contract_data['provider_email']]
    ]
    
    provider_table = Table(provider_info, colWidths=[1.5*inch, 4.5*inch])
    provider_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(provider_table)
    story.append(Spacer(1, 10))
    
    # Client
    client_title = Paragraph("Client:", styles['Heading3'])
    story.append(client_title)
    
    client_info = [
        ['Company Name:', contract_data['client_name']],
        ['Address:', contract_data['client_address']],
        ['Contact Person:', contract_data['client_contact']],
        ['Phone:', contract_data['client_phone']],
        ['Email:', contract_data['client_email']]
    ]
    
    client_table = Table(client_info, colWidths=[1.5*inch, 4.5*inch])
    client_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(client_table)
    story.append(Spacer(1, 20))
    
    # Scope of work
    scope_title = Paragraph("SCOPE OF WORK", styles['Heading2'])
    story.append(scope_title)
    
    scope_text = f"""
    The Service Provider agrees to provide the following services:
    
    {contract_data['scope_of_work']}
    
    Services will be performed at the following location(s):
    {contract_data['service_location']}
    
    Expected completion date: {contract_data['completion_date']}
    """
    
    scope_para = Paragraph(scope_text, styles['Normal'])
    story.append(scope_para)
    story.append(Spacer(1, 20))
    
    # Payment terms
    payment_title = Paragraph("PAYMENT TERMS", styles['Heading2'])
    story.append(payment_title)
    
    payment_data = [
        ['Payment Schedule', 'Amount', 'Due Date'],
        ['Initial Payment', f"${contract_data['initial_payment']:,}", contract_data['initial_due_date']],
        ['Progress Payment 1', f"${contract_data['progress_payment_1']:,}", contract_data['progress_due_1']],
        ['Progress Payment 2', f"${contract_data['progress_payment_2']:,}", contract_data['progress_due_2']],
        ['Final Payment', f"${contract_data['final_payment']:,}", contract_data['final_due_date']],
        ['Total Contract Value', f"${contract_data['total_payments']:,}", '']
    ]
    
    payment_table = Table(payment_data, colWidths=[2.5*inch, 1.5*inch, 2*inch])
    payment_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(payment_table)
    story.append(Spacer(1, 20))
    
    # Insurance requirements
    insurance_title = Paragraph("INSURANCE REQUIREMENTS", styles['Heading2'])
    story.append(insurance_title)
    
    insurance_text = f"""
    The Service Provider shall maintain the following minimum insurance coverage:
    
    • General Liability: ${contract_data['required_gl_coverage']:,} per occurrence
    • Professional Liability: ${contract_data['required_pl_coverage']:,} per claim
    • Workers' Compensation: As required by state law
    • Commercial Auto: ${contract_data['required_auto_coverage']:,} combined single limit
    
    The Client shall be named as an additional insured on all applicable policies.
    Certificates of Insurance must be provided before work commences.
    """
    
    insurance_para = Paragraph(insurance_text, styles['Normal'])
    story.append(insurance_para)
    story.append(Spacer(1, 20))
    
    # Signatures
    signature_title = Paragraph("SIGNATURES", styles['Heading2'])
    story.append(signature_title)
    
    signature_data = [
        ['Service Provider', '', 'Client', ''],
        ['', '', '', ''],
        ['Signature: _________________', 'Date: ________', 'Signature: _________________', 'Date: ________'],
        ['', '', '', ''],
        [f'Print Name: {contract_data["provider_signatory"]}', '', f'Print Name: {contract_data["client_signatory"]}', ''],
        [f'Title: {contract_data["provider_title"]}', '', f'Title: {contract_data["client_title"]}', '']
    ]
    
    signature_table = Table(signature_data, colWidths=[1.5*inch, 1.5*inch, 1.5*inch, 1.5*inch])
    signature_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(signature_table)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_risk_assessment(filename, risk_data):
    """Create a risk assessment report"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("BUSINESS RISK ASSESSMENT REPORT", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Assessment details
    assessment_info = [
        ['Assessment ID:', risk_data['assessment_id']],
        ['Assessment Date:', risk_data['assessment_date']],
        ['Conducted By:', risk_data['assessor_name']],
        ['Company Assessed:', risk_data['company_name']],
        ['Industry:', risk_data['industry']],
        ['Assessment Type:', risk_data['assessment_type']]
    ]
    
    info_table = Table(assessment_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Executive summary
    summary_title = Paragraph("EXECUTIVE SUMMARY", styles['Heading2'])
    story.append(summary_title)
    
    summary_text = f"""
    Overall Risk Rating: {risk_data['overall_risk_rating']}
    
    This risk assessment evaluates the potential liability exposures for {risk_data['company_name']}.
    Based on our analysis, the company presents a {risk_data['overall_risk_rating'].lower()} risk profile 
    for general liability insurance purposes.
    
    Key areas of concern include {risk_data['key_concerns']} while strengths include {risk_data['strengths']}.
    """
    
    summary_para = Paragraph(summary_text, styles['Normal'])
    story.append(summary_para)
    story.append(Spacer(1, 20))
    
    # Risk categories
    categories_title = Paragraph("RISK CATEGORY ANALYSIS", styles['Heading2'])
    story.append(categories_title)
    
    categories_data = [
        ['Risk Category', 'Risk Level', 'Impact', 'Likelihood', 'Mitigation Measures'],
        ['Premises Liability', risk_data['premises_risk'], 'High', 'Medium', 'Regular inspections, maintenance'],
        ['Product Liability', risk_data['product_risk'], 'Medium', 'Low', 'Quality control, testing'],
        ['Professional Liability', risk_data['professional_risk'], 'High', 'Medium', 'Training, procedures'],
        ['Cyber Security', risk_data['cyber_risk'], 'High', 'High', 'Security systems, training'],
        ['Employment Practices', risk_data['employment_risk'], 'Medium', 'Low', 'HR policies, training'],
        ['Environmental', risk_data['environmental_risk'], 'Low', 'Low', 'Compliance monitoring']
    ]
    
    categories_table = Table(categories_data, colWidths=[1.5*inch, 1*inch, 1*inch, 1*inch, 1.5*inch])
    categories_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(categories_table)
    story.append(Spacer(1, 20))
    
    # Recommendations
    recommendations_title = Paragraph("RECOMMENDATIONS", styles['Heading2'])
    story.append(recommendations_title)
    
    recommendations_text = f"""
    Based on this risk assessment, we recommend the following:
    
    1. Insurance Coverage:
       • General Liability: ${risk_data['recommended_gl_limit']:,} per occurrence
       • Professional Liability: ${risk_data['recommended_pl_limit']:,} per claim
       • Cyber Liability: ${risk_data['recommended_cyber_limit']:,} per incident
    
    2. Risk Management Improvements:
       • {risk_data['improvement_1']}
       • {risk_data['improvement_2']}
       • {risk_data['improvement_3']}
    
    3. Review Schedule:
       • Annual risk assessment review
       • Quarterly policy updates as needed
       • Immediate notification of significant business changes
    
    Implementation of these recommendations should reduce the overall risk profile and 
    potentially lead to more favorable insurance terms.
    """
    
    recommendations_para = Paragraph(recommendations_text, styles['Normal'])
    story.append(recommendations_para)
    story.append(Spacer(1, 20))
    
    # Assessor certification
    cert_title = Paragraph("ASSESSOR CERTIFICATION", styles['Heading2'])
    story.append(cert_title)
    
    cert_text = f"""
    This assessment was conducted in accordance with industry standard risk assessment practices.
    The information contained in this report is based on data provided by the client and 
    observations made during the assessment process.
    
    Assessor: {risk_data['assessor_signature']}
    Certification: {risk_data['assessor_certification']}
    Date: {risk_data['signature_date']}
    """
    
    cert_para = Paragraph(cert_text, styles['Normal'])
    story.append(cert_para)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def generate_liability_insurance_docs():
    """Generate all liability insurance documents"""
    # Sample data
    business_data = {
        'registration_number': 'BRN-2024-456789',
        'issue_date': '2024-01-15',
        'expiration_date': '2025-01-15',
        'business_name': 'TechSolutions Consulting LLC',
        'dba_name': 'TechSolutions',
        'business_type': 'Limited Liability Company',
        'industry': 'Information Technology Services',
        'federal_ein': '12-3456789',
        'state_tax_id': 'ST-789456123',
        'street_address': '456 Innovation Drive, Suite 200',
        'city': 'Chicago',
        'state': 'Illinois',
        'zip_code': '60601',
        'phone': '(312) 555-0123',
        'email': 'info@techsolutions.com',
        'principal_owner': 'Jennifer Martinez',
        'owner_title': 'Managing Member',
        'ownership_percentage': '75%',
        'owner_address': '123 Elm Street, Chicago, IL 60602',
        'activities': [
            'Software development and consulting',
            'IT infrastructure design and implementation',
            'Cybersecurity consulting',
            'Data analytics and business intelligence',
            'Cloud computing services'
        ]
    }
    
    financial_data = {
        'company_name': 'TechSolutions Consulting LLC',
        'period_start': '2024-01-01',
        'period_end': '2024-12-31',
        'statement_date': '2024-12-31',
        'prepared_by': 'Johnson & Associates CPA',
        'cpa_firm': 'Johnson & Associates CPA',
        'cash': 125000,
        'accounts_receivable': 85000,
        'inventory': 15000,
        'prepaid_expenses': 12000,
        'total_current_assets': 237000,
        'ppe': 95000,
        'accumulated_depreciation': 28000,
        'net_fixed_assets': 67000,
        'total_assets': 304000,
        'accounts_payable': 45000,
        'accrued_expenses': 22000,
        'short_term_debt': 18000,
        'total_current_liabilities': 85000,
        'long_term_debt': 45000,
        'total_liabilities': 130000,
        'common_stock': 50000,
        'retained_earnings': 124000,
        'total_equity': 174000,
        'total_liab_equity': 304000,
        'revenue': 850000,
        'cogs': 425000,
        'gross_profit': 425000,
        'salaries': 245000,
        'rent_utilities': 48000,
        'marketing': 25000,
        'professional_services': 15000,
        'other_expenses': 32000,
        'total_operating_expenses': 365000,
        'operating_income': 60000,
        'interest_expense': 5000,
        'income_before_taxes': 55000,
        'tax_expense': 12000,
        'net_income': 43000
    }
    
    policy_data = {
        'policy_number': 'GL-2024-789012',
        'effective_date': '2024-01-01',
        'expiration_date': '2024-12-31',
        'insurance_company': 'Metropolitan Business Insurance Co.',
        'agent_name': 'Sarah Thompson, CIC',
        'issue_date': '2023-12-15',
        'business_name': 'TechSolutions Consulting LLC',
        'business_address': '456 Innovation Drive, Suite 200, Chicago, IL 60601',
        'business_phone': '(312) 555-0123',
        'principal_contact': 'Jennifer Martinez',
        'industry_classification': 'Computer Systems Design Services',
        'each_occurrence': 1000000,
        'general_aggregate': 2000000,
        'personal_injury_limit': 1000000,
        'products_ops_occurrence': 1000000,
        'products_ops_aggregate': 2000000,
        'medical_expenses': 5000,
        'bd_pd_premium': 2850,
        'personal_injury_premium': 450,
        'products_ops_premium': 675,
        'medical_premium': 125,
        'total_premium': 4100,
        'deductible': 2500,
        'claims_phone': '(800) 555-CLAIM',
        'claims_hotline': '(800) 555-2524',
        'claims_website': 'www.metrobusiness.com/claims'
    }
    
    contract_data = {
        'contract_number': 'SA-2024-3456',
        'effective_date': '2024-09-01',
        'contract_term': '12 months',
        'contract_value': 125000,
        'provider_name': 'TechSolutions Consulting LLC',
        'provider_address': '456 Innovation Drive, Suite 200, Chicago, IL 60601',
        'provider_contact': 'Jennifer Martinez',
        'provider_phone': '(312) 555-0123',
        'provider_email': 'jennifer@techsolutions.com',
        'client_name': 'Global Manufacturing Corp',
        'client_address': '789 Industrial Blvd, Springfield, IL 62701',
        'client_contact': 'Robert Johnson',
        'client_phone': '(217) 555-7890',
        'client_email': 'rjohnson@globalmanufacturing.com',
        'scope_of_work': '''Implementation of comprehensive ERP system including:
• System analysis and requirements gathering
• Software configuration and customization  
• Data migration from legacy systems
• User training and documentation
• Go-live support and warranty period''',
        'service_location': 'Client facilities at 789 Industrial Blvd, Springfield, IL 62701',
        'completion_date': '2025-02-28',
        'initial_payment': 31250,
        'initial_due_date': '2024-09-15',
        'progress_payment_1': 37500,
        'progress_due_1': '2024-11-30',
        'progress_payment_2': 37500,
        'progress_due_2': '2025-01-31',
        'final_payment': 18750,
        'final_due_date': '2025-03-15',
        'total_payments': 125000,
        'required_gl_coverage': 1000000,
        'required_pl_coverage': 1000000,
        'required_auto_coverage': 500000,
        'provider_signatory': 'Jennifer Martinez',
        'provider_title': 'Managing Member',
        'client_signatory': 'Robert Johnson',
        'client_title': 'IT Director'
    }
    
    risk_data = {
        'assessment_id': 'RA-2024-7890',
        'assessment_date': '2024-08-15',
        'assessor_name': 'Michael Davis, ARM',
        'company_name': 'TechSolutions Consulting LLC',
        'industry': 'Information Technology Services',
        'assessment_type': 'Comprehensive Liability Risk Assessment',
        'overall_risk_rating': 'MODERATE',
        'key_concerns': 'cyber security exposures and professional liability risks',
        'strengths': 'strong financial position and established risk management procedures',
        'premises_risk': 'Low',
        'product_risk': 'Medium', 
        'professional_risk': 'High',
        'cyber_risk': 'High',
        'employment_risk': 'Low',
        'environmental_risk': 'Low',
        'recommended_gl_limit': 1000000,
        'recommended_pl_limit': 2000000,
        'recommended_cyber_limit': 1000000,
        'improvement_1': 'Implement formal cybersecurity training program',
        'improvement_2': 'Establish written professional services standards',
        'improvement_3': 'Regular third-party security assessments',
        'assessor_signature': 'Michael Davis, ARM',
        'assessor_certification': 'Associate in Risk Management (ARM)',
        'signature_date': '2024-08-20'
    }
    
    # Generate documents
    create_business_registration('test-documents/liability-insurance/business_registration_certificate.pdf', business_data)
    create_financial_statement('test-documents/liability-insurance/financial_statement.pdf', financial_data)
    create_liability_policy('test-documents/liability-insurance/liability_insurance_policy.pdf', policy_data)
    create_contract_document('test-documents/liability-insurance/service_contract.pdf', contract_data)
    create_risk_assessment('test-documents/liability-insurance/risk_assessment_report.pdf', risk_data)

if __name__ == "__main__":
    generate_liability_insurance_docs()
    print("Liability insurance documents generated successfully!")