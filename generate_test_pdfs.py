#!/usr/bin/env python3
"""
Generate sample PDF documents for insurance testing
All content is fictional and for testing purposes only
"""

from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
from reportlab.lib.units import inch
from reportlab.lib import colors
import os
from datetime import datetime, timedelta
import random

def create_vehicle_registration(filename, vehicle_data):
    """Create a sample vehicle registration certificate"""
    c = canvas.Canvas(filename, pagesize=letter)
    width, height = letter
    
    # Header
    c.setFont("Helvetica-Bold", 16)
    c.drawString(50, height - 50, "DEPARTMENT OF MOTOR VEHICLES")
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, height - 80, "CERTIFICATE OF REGISTRATION")
    
    # Document number
    c.setFont("Helvetica", 10)
    c.drawString(width - 200, height - 50, f"Document No: {vehicle_data['doc_number']}")
    c.drawString(width - 200, height - 70, f"Issue Date: {vehicle_data['issue_date']}")
    
    # Vehicle details
    y_pos = height - 150
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "VEHICLE INFORMATION")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    details = [
        ("Registration Number:", vehicle_data['reg_number']),
        ("Vehicle Make:", vehicle_data['make']),
        ("Vehicle Model:", vehicle_data['model']),
        ("Year of Manufacture:", vehicle_data['year']),
        ("Engine Number:", vehicle_data['engine_number']),
        ("Chassis Number:", vehicle_data['chassis_number']),
        ("Color:", vehicle_data['color']),
        ("Fuel Type:", vehicle_data['fuel_type'])
    ]
    
    for label, value in details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Owner details
    y_pos -= 20
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "OWNER INFORMATION")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    owner_details = [
        ("Full Name:", vehicle_data['owner_name']),
        ("Address:", vehicle_data['owner_address']),
        ("ID Number:", vehicle_data['owner_id']),
        ("Phone:", vehicle_data['owner_phone'])
    ]
    
    for label, value in owner_details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Footer
    c.setFont("Helvetica", 8)
    c.drawString(50, 50, "This is a sample document for testing purposes only")
    c.drawString(50, 35, "All information contained herein is fictional")
    
    c.save()

def create_drivers_license(filename, driver_data):
    """Create a sample driver's license"""
    c = canvas.Canvas(filename, pagesize=(4*inch, 2.5*inch))
    width, height = 4*inch, 2.5*inch
    
    # Front side
    c.setFillColor(colors.lightblue)
    c.rect(0, 0, width, height, fill=1)
    
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(10, height - 20, "DRIVER LICENSE")
    
    c.setFont("Helvetica", 8)
    c.drawString(10, height - 40, f"License No: {driver_data['license_number']}")
    c.drawString(10, height - 55, f"Class: {driver_data['license_class']}")
    c.drawString(10, height - 70, f"Expires: {driver_data['expiry_date']}")
    
    # Driver info
    c.drawString(10, height - 95, f"Name: {driver_data['full_name']}")
    c.drawString(10, height - 110, f"DOB: {driver_data['date_of_birth']}")
    c.drawString(10, height - 125, f"Address: {driver_data['address']}")
    
    # Photo placeholder
    c.setFillColor(colors.grey)
    c.rect(width - 80, height - 120, 70, 90, fill=1)
    c.setFillColor(colors.white)
    c.setFont("Helvetica", 6)
    c.drawString(width - 75, height - 70, "PHOTO")
    
    c.showPage()
    
    # Back side
    c.setFillColor(colors.lightgrey)
    c.rect(0, 0, width, height, fill=1)
    
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(10, height - 20, "RESTRICTIONS & ENDORSEMENTS")
    
    c.setFont("Helvetica", 7)
    restrictions = driver_data.get('restrictions', ['NONE'])
    y_pos = height - 40
    for restriction in restrictions:
        c.drawString(10, y_pos, f"• {restriction}")
        y_pos -= 15
    
    c.drawString(10, 20, "This is a sample document for testing purposes only")
    
    c.save()

def create_vehicle_inspection_report(filename, inspection_data):
    """Create a vehicle inspection report"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("VEHICLE INSPECTION REPORT", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Inspection details
    inspection_info = [
        ['Inspection Date:', inspection_data['inspection_date']],
        ['Inspector:', inspection_data['inspector_name']],
        ['License No:', inspection_data['inspector_license']],
        ['Station:', inspection_data['station_name']],
        ['Certificate No:', inspection_data['certificate_number']]
    ]
    
    info_table = Table(inspection_info, colWidths=[2*inch, 3*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Vehicle details
    vehicle_title = Paragraph("VEHICLE DETAILS", styles['Heading2'])
    story.append(vehicle_title)
    
    vehicle_info = [
        ['Registration No:', inspection_data['reg_number']],
        ['Make/Model:', f"{inspection_data['make']} {inspection_data['model']}"],
        ['Year:', inspection_data['year']],
        ['Mileage:', inspection_data['mileage']],
        ['VIN:', inspection_data['vin']]
    ]
    
    vehicle_table = Table(vehicle_info, colWidths=[2*inch, 3*inch])
    vehicle_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(vehicle_table)
    story.append(Spacer(1, 20))
    
    # Inspection results
    results_title = Paragraph("INSPECTION RESULTS", styles['Heading2'])
    story.append(results_title)
    
    inspection_items = [
        ['Component', 'Status', 'Notes'],
        ['Brakes', 'PASS', 'Good condition'],
        ['Lights', 'PASS', 'All functional'],
        ['Tires', 'PASS', '7/32" tread depth'],
        ['Steering', 'PASS', 'No play detected'],
        ['Exhaust', 'PASS', 'Secure mounting'],
        ['Mirrors', 'PASS', 'Clean and secure'],
        ['Windshield', 'PASS', 'No cracks'],
        ['Horn', 'PASS', 'Audible'],
        ['Seat Belts', 'PASS', 'Functional']
    ]
    
    results_table = Table(inspection_items, colWidths=[2*inch, 1*inch, 2.5*inch])
    results_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(results_table)
    story.append(Spacer(1, 20))
    
    # Conclusion
    conclusion = Paragraph(f"<b>OVERALL RESULT: {inspection_data['result']}</b>", styles['Normal'])
    story.append(conclusion)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_insurance_policy(filename, policy_data):
    """Create an insurance policy document"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Header
    title = Paragraph("MOTOR VEHICLE INSURANCE POLICY", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Policy details
    policy_info = [
        ['Policy Number:', policy_data['policy_number']],
        ['Policy Period:', f"{policy_data['start_date']} to {policy_data['end_date']}"],
        ['Insurance Company:', policy_data['company_name']],
        ['Agent:', policy_data['agent_name']],
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
    
    # Insured details
    insured_title = Paragraph("INSURED INFORMATION", styles['Heading2'])
    story.append(insured_title)
    
    insured_info = [
        ['Name:', policy_data['insured_name']],
        ['Address:', policy_data['insured_address']],
        ['Phone:', policy_data['insured_phone']],
        ['Email:', policy_data['insured_email']],
        ['License Number:', policy_data['license_number']]
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
    
    # Vehicle details
    vehicle_title = Paragraph("COVERED VEHICLE", styles['Heading2'])
    story.append(vehicle_title)
    
    vehicle_info = [
        ['Year/Make/Model:', f"{policy_data['vehicle_year']} {policy_data['vehicle_make']} {policy_data['vehicle_model']}"],
        ['VIN:', policy_data['vehicle_vin']],
        ['License Plate:', policy_data['license_plate']],
        ['Use:', policy_data['vehicle_use']]
    ]
    
    vehicle_table = Table(vehicle_info, colWidths=[2*inch, 4*inch])
    vehicle_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(vehicle_table)
    story.append(Spacer(1, 20))
    
    # Coverage details
    coverage_title = Paragraph("COVERAGE DETAILS", styles['Heading2'])
    story.append(coverage_title)
    
    coverage_data = [
        ['Coverage Type', 'Limit', 'Deductible', 'Premium'],
        ['Liability - Bodily Injury', '$100,000/$300,000', 'N/A', '$450.00'],
        ['Liability - Property Damage', '$50,000', 'N/A', '$200.00'],
        ['Comprehensive', 'ACV', '$500', '$180.00'],
        ['Collision', 'ACV', '$500', '$220.00'],
        ['Uninsured Motorist', '$100,000/$300,000', 'N/A', '$75.00'],
        ['', '', 'Total Annual Premium:', '$1,125.00']
    ]
    
    coverage_table = Table(coverage_data, colWidths=[2.5*inch, 1.5*inch, 1*inch, 1*inch])
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
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_claim_form(filename, claim_data, is_blank=False):
    """Create a claim form (blank or completed)"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("MOTOR INSURANCE CLAIM FORM", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    if not is_blank:
        story.append(Paragraph(f"Claim Number: {claim_data['claim_number']}", styles['Normal']))
        story.append(Paragraph(f"Date of Report: {claim_data['report_date']}", styles['Normal']))
    else:
        story.append(Paragraph("Claim Number: ________________________", styles['Normal']))
        story.append(Paragraph("Date of Report: ________________________", styles['Normal']))
    
    story.append(Spacer(1, 20))
    
    # Section 1: Policy Information
    section1 = Paragraph("SECTION 1: POLICY INFORMATION", styles['Heading2'])
    story.append(section1)
    
    if not is_blank:
        policy_info = [
            f"Policy Number: {claim_data['policy_number']}",
            f"Insured Name: {claim_data['insured_name']}",
            f"Phone Number: {claim_data['phone']}",
            f"Email: {claim_data['email']}"
        ]
        for info in policy_info:
            story.append(Paragraph(info, styles['Normal']))
    else:
        blank_fields = [
            "Policy Number: ________________________________________________",
            "Insured Name: ________________________________________________",
            "Phone Number: ________________________________________________",
            "Email: ________________________________________________"
        ]
        for field in blank_fields:
            story.append(Paragraph(field, styles['Normal']))
    
    story.append(Spacer(1, 20))
    
    # Section 2: Incident Details
    section2 = Paragraph("SECTION 2: INCIDENT DETAILS", styles['Heading2'])
    story.append(section2)
    
    if not is_blank:
        incident_info = [
            f"Date of Loss: {claim_data['loss_date']}",
            f"Time of Loss: {claim_data['loss_time']}",
            f"Location: {claim_data['location']}",
            f"Description: {claim_data['description']}"
        ]
        for info in incident_info:
            story.append(Paragraph(info, styles['Normal']))
    else:
        incident_fields = [
            "Date of Loss: ________________________________________________",
            "Time of Loss: ________________________________________________",
            "Location: ________________________________________________",
            "Description of Incident:",
            "________________________________________________________________",
            "________________________________________________________________",
            "________________________________________________________________"
        ]
        for field in incident_fields:
            story.append(Paragraph(field, styles['Normal']))
    
    story.append(Spacer(1, 20))
    
    # Section 3: Vehicle Information
    section3 = Paragraph("SECTION 3: VEHICLE INFORMATION", styles['Heading2'])
    story.append(section3)
    
    if not is_blank:
        vehicle_info = [
            f"Year/Make/Model: {claim_data['vehicle']}",
            f"License Plate: {claim_data['license_plate']}",
            f"VIN: {claim_data['vin']}",
            f"Estimated Damage: ${claim_data['estimated_damage']}"
        ]
        for info in vehicle_info:
            story.append(Paragraph(info, styles['Normal']))
    else:
        vehicle_fields = [
            "Year/Make/Model: ________________________________________________",
            "License Plate: ________________________________________________",
            "VIN: ________________________________________________",
            "Estimated Damage: $________________________________________________"
        ]
        for field in vehicle_fields:
            story.append(Paragraph(field, styles['Normal']))
    
    story.append(Spacer(1, 30))
    
    # Signature section
    signature_section = Paragraph("CERTIFICATION", styles['Heading2'])
    story.append(signature_section)
    
    cert_text = "I certify that the information provided above is true and accurate to the best of my knowledge."
    story.append(Paragraph(cert_text, styles['Normal']))
    story.append(Spacer(1, 20))
    
    if not is_blank:
        story.append(Paragraph(f"Signature: {claim_data['signature']}", styles['Normal']))
        story.append(Paragraph(f"Date: {claim_data['signature_date']}", styles['Normal']))
    else:
        story.append(Paragraph("Signature: ________________________________________________", styles['Normal']))
        story.append(Paragraph("Date: ________________________________________________", styles['Normal']))
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def generate_motor_insurance_docs():
    """Generate all motor insurance documents"""
    # Sample data
    vehicle_data_1 = {
        'doc_number': 'REG-2024-001234',
        'issue_date': '2024-03-15',
        'reg_number': 'ABC-123-DE',
        'make': 'Toyota',
        'model': 'Camry',
        'year': '2022',
        'engine_number': 'ENG789456123',
        'chassis_number': 'CHS456789012',
        'color': 'Silver',
        'fuel_type': 'Gasoline',
        'owner_name': 'John Michael Smith',
        'owner_address': '123 Main Street, Springfield, IL 62701',
        'owner_id': 'ID123456789',
        'owner_phone': '(555) 123-4567'
    }
    
    vehicle_data_2 = {
        'doc_number': 'REG-2024-005678',
        'issue_date': '2024-01-22',
        'reg_number': 'XYZ-789-FG',
        'make': 'Honda',
        'model': 'Civic',
        'year': '2023',
        'engine_number': 'ENG321654987',
        'chassis_number': 'CHS987654321',
        'color': 'Blue',
        'fuel_type': 'Gasoline',
        'owner_name': 'Sarah Elizabeth Johnson',
        'owner_address': '456 Oak Avenue, Chicago, IL 60601',
        'owner_id': 'ID987654321',
        'owner_phone': '(555) 987-6543'
    }
    
    driver_data_1 = {
        'license_number': 'DL123456789',
        'license_class': 'Class C',
        'expiry_date': '2027-05-15',
        'full_name': 'John Michael Smith',
        'date_of_birth': '1985-08-22',
        'address': '123 Main Street, Springfield, IL',
        'restrictions': ['CORRECTIVE LENSES']
    }
    
    driver_data_2 = {
        'license_number': 'DL987654321',
        'license_class': 'Class C',
        'expiry_date': '2026-11-30',
        'full_name': 'Sarah Elizabeth Johnson',
        'date_of_birth': '1990-03-10',
        'address': '456 Oak Avenue, Chicago, IL',
        'restrictions': ['NONE']
    }
    
    inspection_data = {
        'inspection_date': '2024-08-15',
        'inspector_name': 'Robert Wilson',
        'inspector_license': 'INS-54321',
        'station_name': 'Central Auto Inspection Station',
        'certificate_number': 'CERT-2024-789',
        'reg_number': 'ABC-123-DE',
        'make': 'Toyota',
        'model': 'Camry',
        'year': '2022',
        'mileage': '25,485',
        'vin': '1HGCM82633A123456',
        'result': 'PASS'
    }
    
    policy_data = {
        'policy_number': 'POL-2024-567890',
        'start_date': '2024-01-01',
        'end_date': '2024-12-31',
        'company_name': 'Sample Insurance Company',
        'agent_name': 'Michael Thompson',
        'issue_date': '2023-12-15',
        'insured_name': 'John Michael Smith',
        'insured_address': '123 Main Street, Springfield, IL 62701',
        'insured_phone': '(555) 123-4567',
        'insured_email': 'john.smith@email.com',
        'license_number': 'DL123456789',
        'vehicle_year': '2022',
        'vehicle_make': 'Toyota',
        'vehicle_model': 'Camry',
        'vehicle_vin': '1HGCM82633A123456',
        'license_plate': 'ABC-123-DE',
        'vehicle_use': 'Personal'
    }
    
    claim_data = {
        'claim_number': 'CLM-2024-001234',
        'report_date': '2024-09-10',
        'policy_number': 'POL-2024-567890',
        'insured_name': 'John Michael Smith',
        'phone': '(555) 123-4567',
        'email': 'john.smith@email.com',
        'loss_date': '2024-09-08',
        'loss_time': '2:30 PM',
        'location': 'Intersection of Main St and Oak Ave, Springfield, IL',
        'description': 'Rear-end collision at traffic light. Other driver failed to stop.',
        'vehicle': '2022 Toyota Camry',
        'license_plate': 'ABC-123-DE',
        'vin': '1HGCM82633A123456',
        'estimated_damage': '3,500',
        'signature': 'John M. Smith',
        'signature_date': '2024-09-10'
    }
    
    # Generate documents
    create_vehicle_registration('test-documents/motor-insurance/vehicle_registration_1.pdf', vehicle_data_1)
    create_vehicle_registration('test-documents/motor-insurance/vehicle_registration_2.pdf', vehicle_data_2)
    create_drivers_license('test-documents/motor-insurance/drivers_license_1.pdf', driver_data_1)
    create_drivers_license('test-documents/motor-insurance/drivers_license_2.pdf', driver_data_2)
    create_vehicle_inspection_report('test-documents/motor-insurance/vehicle_inspection_report.pdf', inspection_data)
    create_insurance_policy('test-documents/motor-insurance/insurance_policy.pdf', policy_data)
    create_claim_form('test-documents/motor-insurance/claim_form_completed.pdf', claim_data, False)
    create_claim_form('test-documents/motor-insurance/claim_form_blank.pdf', {}, True)

if __name__ == "__main__":
    generate_motor_insurance_docs()
    print("Motor insurance documents generated successfully!")