#!/usr/bin/env python3
"""
Generate General Forms sample PDF documents for testing
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

def create_id_card(filename, id_data):
    """Create a sample ID card (redacted for privacy)"""
    c = canvas.Canvas(filename, pagesize=(3.375*inch, 2.125*inch))
    width, height = 3.375*inch, 2.125*inch
    
    # Front side
    c.setFillColor(colors.lightblue)
    c.rect(0, 0, width, height, fill=1)
    
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(5, height - 15, "IDENTIFICATION CARD")
    
    c.setFont("Helvetica", 6)
    c.drawString(5, height - 30, f"ID Number: {id_data['id_number']}")
    c.drawString(5, height - 42, f"Issued: {id_data['issue_date']}")
    c.drawString(5, height - 54, f"Expires: {id_data['expiry_date']}")
    
    # Personal info (redacted)
    c.drawString(5, height - 75, f"Name: {id_data['name_redacted']}")
    c.drawString(5, height - 87, f"DOB: {id_data['dob_redacted']}")
    c.drawString(5, height - 99, f"Address: {id_data['address_redacted']}")
    
    # Photo placeholder
    c.setFillColor(colors.grey)
    c.rect(width - 60, height - 90, 55, 70, fill=1)
    c.setFillColor(colors.white)
    c.setFont("Helvetica", 5)
    c.drawString(width - 55, height - 55, "PHOTO")
    c.drawString(width - 58, height - 48, "REDACTED")
    
    # Redaction notice
    c.setFillColor(colors.red)
    c.setFont("Helvetica-Bold", 5)
    c.drawString(5, 10, "SAMPLE DOCUMENT - PERSONAL INFO REDACTED FOR PRIVACY")
    
    c.save()

def create_passport_sample(filename, passport_data):
    """Create a sample passport page (redacted for privacy)"""
    c = canvas.Canvas(filename, pagesize=(4.25*inch, 5.5*inch))
    width, height = 4.25*inch, 5.5*inch
    
    # Background
    c.setFillColor(colors.lightcyan)
    c.rect(0, 0, width, height, fill=1)
    
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(10, height - 25, "UNITED STATES OF AMERICA")
    c.setFont("Helvetica-Bold", 8)
    c.drawString(10, height - 40, "PASSPORT")
    
    # Document info
    c.setFont("Helvetica", 6)
    c.drawString(10, height - 60, f"Passport No: {passport_data['passport_number']}")
    c.drawString(10, height - 72, f"Type: {passport_data['passport_type']}")
    c.drawString(10, height - 84, f"Issued: {passport_data['issue_date']}")
    c.drawString(10, height - 96, f"Expires: {passport_data['expiry_date']}")
    
    # Personal data (redacted)
    c.setFont("Helvetica-Bold", 7)
    c.drawString(10, height - 120, "PERSONAL DATA (REDACTED)")
    
    c.setFont("Helvetica", 6)
    personal_data = [
        f"Surname: {passport_data['surname_redacted']}",
        f"Given Names: {passport_data['given_names_redacted']}",
        f"Nationality: {passport_data['nationality']}",
        f"Date of Birth: {passport_data['dob_redacted']}",
        f"Place of Birth: {passport_data['pob_redacted']}",
        f"Sex: {passport_data['sex_redacted']}"
    ]
    
    y_pos = height - 140
    for data in personal_data:
        c.drawString(10, y_pos, data)
        y_pos -= 12
    
    # Photo area
    c.setFillColor(colors.grey)
    c.rect(width - 80, height - 180, 70, 90, fill=1)
    c.setFillColor(colors.white)
    c.setFont("Helvetica", 5)
    c.drawString(width - 75, height - 135, "PHOTO")
    c.drawString(width - 78, height - 128, "REDACTED")
    
    # Machine readable zone (redacted)
    c.setFillColor(colors.darkgrey)
    c.rect(10, 20, width - 20, 30, fill=1)
    c.setFillColor(colors.white)
    c.setFont("Courier", 5)
    c.drawString(15, 40, "P<USA" + "X" * 25)
    c.drawString(15, 32, "X" * 30)
    c.drawString(15, 24, "MACHINE READABLE ZONE REDACTED")
    
    # Redaction notice
    c.setFillColor(colors.red)
    c.setFont("Helvetica-Bold", 5)
    c.drawString(10, 5, "SAMPLE DOCUMENT - PERSONAL INFO REDACTED FOR PRIVACY")
    
    c.save()

def create_proof_of_address(filename, address_data):
    """Create a proof of address document (utility bill style)"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Company header
    title = Paragraph("CITY UTILITIES COMPANY", styles['Title'])
    story.append(title)
    story.append(Paragraph("123 Utility Street, Springfield, IL 62701", styles['Normal']))
    story.append(Paragraph("Phone: (555) 123-UTIL | www.cityutilities.com", styles['Normal']))
    story.append(Spacer(1, 20))
    
    # Account info
    account_info = [
        ['Account Number:', address_data['account_number']],
        ['Service Address:', address_data['service_address']],
        ['Billing Period:', f"{address_data['billing_start']} to {address_data['billing_end']}"],
        ['Bill Date:', address_data['bill_date']],
        ['Due Date:', address_data['due_date']]
    ]
    
    info_table = Table(account_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Customer info
    customer_title = Paragraph("BILLING INFORMATION", styles['Heading2'])
    story.append(customer_title)
    
    customer_info = [
        ['Customer Name:', address_data['customer_name']],
        ['Billing Address:', address_data['billing_address']],
        ['Account Type:', address_data['account_type']],
        ['Service Type:', address_data['service_type']]
    ]
    
    customer_table = Table(customer_info, colWidths=[2*inch, 4*inch])
    customer_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(customer_table)
    story.append(Spacer(1, 20))
    
    # Usage and charges
    charges_title = Paragraph("CURRENT CHARGES", styles['Heading2'])
    story.append(charges_title)
    
    charges_data = [
        ['Service', 'Usage', 'Rate', 'Amount'],
        ['Electricity', f"{address_data['kwh_usage']} kWh", f"${address_data['kwh_rate']:.4f}/kWh", f"${address_data['electric_charge']:.2f}"],
        ['Natural Gas', f"{address_data['gas_usage']} Therms", f"${address_data['gas_rate']:.4f}/Therm", f"${address_data['gas_charge']:.2f}"],
        ['Water/Sewer', f"{address_data['water_usage']} Gallons", f"${address_data['water_rate']:.4f}/Gal", f"${address_data['water_charge']:.2f}"],
        ['Service Fee', '1', f"${address_data['service_fee']:.2f}", f"${address_data['service_fee']:.2f}"],
        ['Taxes', '', '', f"${address_data['taxes']:.2f}"],
        ['Total Amount Due', '', '', f"${address_data['total_due']:.2f}"]
    ]
    
    charges_table = Table(charges_data, colWidths=[1.5*inch, 1*inch, 1*inch, 1*inch])
    charges_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -2), 1, colors.black),
        ('LINEABOVE', (0, -1), (-1, -1), 2, colors.black)
    ]))
    story.append(charges_table)
    story.append(Spacer(1, 20))
    
    # Payment info
    payment_title = Paragraph("PAYMENT INFORMATION", styles['Heading2'])
    story.append(payment_title)
    
    payment_text = f"""
    Please remit payment by {address_data['due_date']}
    
    Payment Options:
    • Online: www.cityutilities.com/pay
    • Phone: (555) 123-UTIL
    • Mail: City Utilities, PO Box 12345, Springfield, IL 62701
    • In Person: 123 Utility Street, Springfield, IL
    
    Thank you for your business!
    """
    
    payment_para = Paragraph(payment_text, styles['Normal'])
    story.append(payment_para)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_bank_statement(filename, bank_data):
    """Create a sample bank statement (redacted)"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Bank header
    title = Paragraph("FIRST NATIONAL BANK", styles['Title'])
    story.append(title)
    story.append(Paragraph("456 Banking Street, Chicago, IL 60601", styles['Normal']))
    story.append(Paragraph("Phone: (312) 555-BANK | www.firstnationalbank.com", styles['Normal']))
    story.append(Spacer(1, 20))
    
    # Statement header
    statement_title = Paragraph("MONTHLY ACCOUNT STATEMENT", styles['Heading1'])
    story.append(statement_title)
    story.append(Spacer(1, 12))
    
    # Account info
    account_info = [
        ['Account Holder:', bank_data['account_holder']],
        ['Account Number:', bank_data['account_number_redacted']],
        ['Account Type:', bank_data['account_type']],
        ['Statement Period:', f"{bank_data['statement_start']} to {bank_data['statement_end']}"],
        ['Statement Date:', bank_data['statement_date']]
    ]
    
    info_table = Table(account_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Account summary
    summary_title = Paragraph("ACCOUNT SUMMARY", styles['Heading2'])
    story.append(summary_title)
    
    summary_info = [
        ['Beginning Balance:', f"${bank_data['beginning_balance']:.2f}"],
        ['Total Deposits:', f"${bank_data['total_deposits']:.2f}"],
        ['Total Withdrawals:', f"${bank_data['total_withdrawals']:.2f}"],
        ['Service Charges:', f"${bank_data['service_charges']:.2f}"],
        ['Interest Earned:', f"${bank_data['interest_earned']:.2f}"],
        ['Ending Balance:', f"${bank_data['ending_balance']:.2f}"]
    ]
    
    summary_table = Table(summary_info, colWidths=[2*inch, 2*inch])
    summary_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LINEABOVE', (0, -1), (-1, -1), 1, colors.black)
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 20))
    
    # Transaction history (sample/redacted)
    transactions_title = Paragraph("TRANSACTION HISTORY (SAMPLE)", styles['Heading2'])
    story.append(transactions_title)
    
    transaction_data = [
        ['Date', 'Description', 'Withdrawal', 'Deposit', 'Balance'],
        [bank_data['statement_start'], 'Beginning Balance', '', '', f"${bank_data['beginning_balance']:.2f}"],
        ['XX/XX/XXXX', 'DEPOSIT - PAYROLL [REDACTED]', '', 'XXX.XX', 'XXX.XX'],
        ['XX/XX/XXXX', 'DEBIT CARD PURCHASE [REDACTED]', 'XXX.XX', '', 'XXX.XX'],
        ['XX/XX/XXXX', 'ONLINE TRANSFER [REDACTED]', 'XXX.XX', '', 'XXX.XX'],
        ['XX/XX/XXXX', 'ATM WITHDRAWAL [REDACTED]', 'XXX.XX', '', 'XXX.XX'],
        ['XX/XX/XXXX', 'DEPOSIT - MOBILE [REDACTED]', '', 'XXX.XX', 'XXX.XX'],
        [bank_data['statement_end'], 'Ending Balance', '', '', f"${bank_data['ending_balance']:.2f}"]
    ]
    
    transaction_table = Table(transaction_data, colWidths=[1*inch, 2.5*inch, 1*inch, 1*inch, 1*inch])
    transaction_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(transaction_table)
    story.append(Spacer(1, 20))
    
    # Redaction notice
    redaction_notice = Paragraph("<b>PRIVACY NOTICE:</b> Specific transaction details and amounts have been redacted for privacy protection. This statement demonstrates format and layout only.", 
                                ParagraphStyle('Notice', fontSize=9, textColor=colors.red))
    story.append(redaction_notice)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_employment_letter(filename, employment_data):
    """Create an employment verification letter"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Company letterhead
    company_title = Paragraph("GLOBAL TECHNOLOGY SOLUTIONS INC.", styles['Title'])
    story.append(company_title)
    story.append(Paragraph("789 Business Park Drive, Suite 500", styles['Normal']))
    story.append(Paragraph("Chicago, Illinois 60601", styles['Normal']))
    story.append(Paragraph("Phone: (312) 555-0199 | Fax: (312) 555-0198", styles['Normal']))
    story.append(Spacer(1, 30))
    
    # Date
    date_para = Paragraph(f"Date: {employment_data['letter_date']}", styles['Normal'])
    story.append(date_para)
    story.append(Spacer(1, 20))
    
    # Subject
    subject_title = Paragraph("EMPLOYMENT VERIFICATION LETTER", styles['Heading1'])
    story.append(subject_title)
    story.append(Spacer(1, 20))
    
    # Salutation
    salutation = Paragraph("To Whom It May Concern:", styles['Normal'])
    story.append(salutation)
    story.append(Spacer(1, 12))
    
    # Body
    body_text = f"""
    This letter serves to verify the employment of <b>{employment_data['employee_name']}</b> 
    with Global Technology Solutions Inc.
    
    Employee Details:
    • Full Name: {employment_data['employee_name']}
    • Employee ID: {employment_data['employee_id']}
    • Position/Title: {employment_data['position']}
    • Department: {employment_data['department']}
    • Employment Status: {employment_data['employment_status']}
    • Employment Start Date: {employment_data['start_date']}
    • Current Employment: {employment_data['current_status']}
    
    Compensation Information:
    • Current Annual Salary: ${employment_data['annual_salary']:,}
    • Pay Frequency: {employment_data['pay_frequency']}
    • Employment Type: {employment_data['employment_type']}
    
    Work Schedule:
    • Standard Hours: {employment_data['standard_hours']} hours per week
    • Work Location: {employment_data['work_location']}
    
    {employment_data['employee_name']} is a valued member of our team and has consistently 
    demonstrated {employment_data['performance_note']}. This employment verification is 
    provided for official purposes only.
    
    If you require any additional information or have questions regarding this verification, 
    please feel free to contact our Human Resources department at (312) 555-0199 ext. 1234 
    or via email at hr@globaltechsolutions.com.
    """
    
    body_para = Paragraph(body_text, styles['Normal'])
    story.append(body_para)
    story.append(Spacer(1, 30))
    
    # Closing
    closing_text = """
    Sincerely,
    
    
    
    
    Sarah Johnson
    Director of Human Resources
    Global Technology Solutions Inc.
    Phone: (312) 555-0199 ext. 1234
    Email: sjohnson@globaltechsolutions.com
    """
    
    closing_para = Paragraph(closing_text, styles['Normal'])
    story.append(closing_para)
    story.append(Spacer(1, 20))
    
    # Disclaimer
    disclaimer = Paragraph("<i>This letter is confidential and intended solely for the purpose stated. Any unauthorized distribution or use is prohibited.</i>", 
                          ParagraphStyle('Disclaimer', fontSize=8, textColor=colors.grey))
    story.append(disclaimer)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 20))
    story.append(footer)
    
    doc.build(story)

def create_medical_certificate(filename, medical_data):
    """Create a medical certificate for general accident insurance"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Medical practice header
    practice_title = Paragraph("SPRINGFIELD MEDICAL CENTER", styles['Title'])
    story.append(practice_title)
    story.append(Paragraph("123 Healthcare Drive, Springfield, IL 62701", styles['Normal']))
    story.append(Paragraph("Phone: (217) 555-CARE | Fax: (217) 555-CARE", styles['Normal']))
    story.append(Spacer(1, 20))
    
    # Certificate title
    cert_title = Paragraph("MEDICAL CERTIFICATE", styles['Heading1'])
    story.append(cert_title)
    story.append(Spacer(1, 12))
    
    # Certificate info
    cert_info = [
        ['Certificate Number:', medical_data['certificate_number']],
        ['Issue Date:', medical_data['issue_date']],
        ['Physician:', medical_data['physician_name']],
        ['License Number:', medical_data['physician_license']],
        ['Specialty:', medical_data['physician_specialty']]
    ]
    
    info_table = Table(cert_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Patient information
    patient_title = Paragraph("PATIENT INFORMATION", styles['Heading2'])
    story.append(patient_title)
    
    patient_info = [
        ['Patient Name:', medical_data['patient_name']],
        ['Date of Birth:', medical_data['patient_dob']],
        ['Patient ID:', medical_data['patient_id']],
        ['Examination Date:', medical_data['examination_date']]
    ]
    
    patient_table = Table(patient_info, colWidths=[2*inch, 4*inch])
    patient_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(patient_table)
    story.append(Spacer(1, 20))
    
    # Medical findings
    findings_title = Paragraph("MEDICAL FINDINGS", styles['Heading2'])
    story.append(findings_title)
    
    findings_text = f"""
    <b>Chief Complaint:</b> {medical_data['chief_complaint']}
    
    <b>History of Present Illness:</b>
    {medical_data['history_present_illness']}
    
    <b>Physical Examination:</b>
    • Vital Signs: BP {medical_data['blood_pressure']}, HR {medical_data['heart_rate']}, 
      Temp {medical_data['temperature']}°F, Resp {medical_data['respiratory_rate']}
    • General Appearance: {medical_data['general_appearance']}
    • Relevant Findings: {medical_data['relevant_findings']}
    
    <b>Diagnostic Tests:</b>
    {medical_data['diagnostic_tests']}
    
    <b>Assessment and Diagnosis:</b>
    {medical_data['diagnosis']}
    
    <b>Treatment Provided:</b>
    {medical_data['treatment']}
    
    <b>Work/Activity Restrictions:</b>
    {medical_data['restrictions']}
    
    <b>Follow-up Care:</b>
    {medical_data['followup']}
    """
    
    findings_para = Paragraph(findings_text, styles['Normal'])
    story.append(findings_para)
    story.append(Spacer(1, 20))
    
    # Physician certification
    cert_text = f"""
    <b>PHYSICIAN CERTIFICATION:</b>
    
    I certify that I have examined the above-named patient on {medical_data['examination_date']} 
    and that the information provided in this certificate is accurate to the best of my 
    medical knowledge and professional judgment.
    
    This certificate is issued for insurance/legal purposes as requested.
    
    Physician Signature: {medical_data['physician_signature']}
    Date: {medical_data['signature_date']}
    
    Dr. {medical_data['physician_name']}, {medical_data['physician_credentials']}
    {medical_data['physician_specialty']}
    License #: {medical_data['physician_license']}
    """
    
    cert_para = Paragraph(cert_text, styles['Normal'])
    story.append(cert_para)
    story.append(Spacer(1, 20))
    
    # Disclaimer
    disclaimer = Paragraph("<i>This medical certificate is confidential and contains protected health information. Distribution is restricted to authorized parties only.</i>", 
                          ParagraphStyle('Disclaimer', fontSize=8, textColor=colors.grey))
    story.append(disclaimer)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 20))
    story.append(footer)
    
    doc.build(story)

def generate_general_forms_docs():
    """Generate all general forms documents"""
    # Sample data
    id_data = {
        'id_number': 'ID-789456123',
        'issue_date': '2022-01-15',
        'expiry_date': '2027-01-15',
        'name_redacted': 'XXXXXXX XXXXXXX',
        'dob_redacted': 'XX/XX/XXXX',
        'address_redacted': 'XXX XXXXXXX ST, XXXXXXX, XX XXXXX'
    }
    
    passport_data = {
        'passport_number': 'XXXXXXXXX',
        'passport_type': 'P',
        'issue_date': '15 JAN 22',
        'expiry_date': '14 JAN 32',
        'surname_redacted': 'XXXXXXX',
        'given_names_redacted': 'XXXXXXX XXXXXXX',
        'nationality': 'USA',
        'dob_redacted': 'XX XXX XX',
        'pob_redacted': 'XXXXXXX, XX, USA',
        'sex_redacted': 'X'
    }
    
    address_data = {
        'account_number': 'UTIL-789456',
        'service_address': '123 Main Street, Springfield, IL 62701',
        'billing_start': '2024-08-01',
        'billing_end': '2024-08-31',
        'bill_date': '2024-09-01',
        'due_date': '2024-09-25',
        'customer_name': 'John M. Smith',
        'billing_address': '123 Main Street, Springfield, IL 62701',
        'account_type': 'Residential',
        'service_type': 'Electric, Gas, Water',
        'kwh_usage': 1245,
        'kwh_rate': 0.1235,
        'electric_charge': 153.76,
        'gas_usage': 45,
        'gas_rate': 0.8950,
        'gas_charge': 40.28,
        'water_usage': 5680,
        'water_rate': 0.0089,
        'water_charge': 50.55,
        'service_fee': 25.00,
        'taxes': 27.18,
        'total_due': 296.77
    }
    
    bank_data = {
        'account_holder': 'John M. Smith',
        'account_number_redacted': 'XXXX-XXXX-XXXX-5678',
        'account_type': 'Personal Checking',
        'statement_start': '2024-08-01',
        'statement_end': '2024-08-31',
        'statement_date': '2024-09-01',
        'beginning_balance': 2847.52,
        'total_deposits': 4250.00,
        'total_withdrawals': 2195.67,
        'service_charges': 15.00,
        'interest_earned': 2.15,
        'ending_balance': 4889.00
    }
    
    employment_data = {
        'letter_date': '2024-09-15',
        'employee_name': 'Jennifer Martinez',
        'employee_id': 'EMP-5678',
        'position': 'Senior Software Engineer',
        'department': 'Information Technology',
        'employment_status': 'Full-Time Regular Employee',
        'start_date': '2021-03-15',
        'current_status': 'Active as of this letter date',
        'annual_salary': 95000,
        'pay_frequency': 'Bi-weekly',
        'employment_type': 'Full-Time Exempt',
        'standard_hours': 40,
        'work_location': 'Chicago, IL Office with Remote Work Options',
        'performance_note': 'excellent technical skills and professional conduct'
    }
    
    medical_data = {
        'certificate_number': 'MED-CERT-789456',
        'issue_date': '2024-09-18',
        'physician_name': 'Dr. Emily Rodriguez',
        'physician_license': 'MD-123456',
        'physician_specialty': 'Family Medicine',
        'patient_name': 'Michael Thompson',
        'patient_dob': '1985-06-22',
        'patient_id': 'PAT-456789',
        'examination_date': '2024-09-15',
        'chief_complaint': 'Follow-up examination after minor motor vehicle accident',
        'history_present_illness': 'Patient was involved in a minor rear-end collision on 2024-09-10. Reports mild neck soreness and headache for 2-3 days following incident. No loss of consciousness. Symptoms improving.',
        'blood_pressure': '128/78',
        'heart_rate': '72',
        'temperature': '98.6',
        'respiratory_rate': '16',
        'general_appearance': 'Alert, well-appearing, no acute distress',
        'relevant_findings': 'Mild cervical muscle tenderness, full range of motion. No neurological deficits.',
        'diagnostic_tests': 'Cervical spine X-rays performed - no fractures or acute abnormalities detected',
        'diagnosis': 'Cervical strain (ICD-10: S13.4), Post-concussion symptoms, mild (ICD-10: F07.81)',
        'treatment': 'NSAIDs for pain management, muscle relaxants as needed, physical therapy referral',
        'restrictions': 'May return to regular activities. Avoid heavy lifting (>20 lbs) for 1 week. Cleared for work with standard duties.',
        'followup': 'Follow-up in 2 weeks if symptoms persist. Return sooner if symptoms worsen.',
        'physician_signature': 'Emily Rodriguez, MD',
        'signature_date': '2024-09-18',
        'physician_credentials': 'MD, FAAFP'
    }
    
    # Generate documents
    create_id_card('test-documents/general-forms/sample_id_card_redacted.pdf', id_data)
    create_passport_sample('test-documents/general-forms/sample_passport_redacted.pdf', passport_data)
    create_proof_of_address('test-documents/general-forms/proof_of_address_utility_bill.pdf', address_data)
    create_bank_statement('test-documents/general-forms/bank_statement_sample.pdf', bank_data)
    create_employment_letter('test-documents/general-forms/employment_verification_letter.pdf', employment_data)
    create_medical_certificate('test-documents/general-forms/medical_certificate.pdf', medical_data)

if __name__ == "__main__":
    generate_general_forms_docs()
    print("General forms documents generated successfully!")