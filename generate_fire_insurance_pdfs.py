#!/usr/bin/env python3
"""
Generate Fire Insurance sample PDF documents for testing
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

def create_property_deed(filename, property_data):
    """Create a sample property deed document"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("PROPERTY DEED", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Document info
    doc_info = Paragraph(f"Deed Number: {property_data['deed_number']}<br/>Recording Date: {property_data['recording_date']}<br/>County: {property_data['county']}", styles['Normal'])
    story.append(doc_info)
    story.append(Spacer(1, 20))
    
    # Legal description
    legal_title = Paragraph("LEGAL DESCRIPTION", styles['Heading2'])
    story.append(legal_title)
    
    legal_text = f"""
    Property legally described as: {property_data['legal_description']}
    
    Street Address: {property_data['street_address']}
    City: {property_data['city']}, State: {property_data['state']}, ZIP: {property_data['zip_code']}
    
    Parcel ID: {property_data['parcel_id']}
    Lot Size: {property_data['lot_size']} square feet
    """
    
    legal_para = Paragraph(legal_text, styles['Normal'])
    story.append(legal_para)
    story.append(Spacer(1, 20))
    
    # Ownership details
    ownership_title = Paragraph("OWNERSHIP INFORMATION", styles['Heading2'])
    story.append(ownership_title)
    
    ownership_data = [
        ['Current Owner(s):', property_data['current_owner']],
        ['Previous Owner:', property_data['previous_owner']],
        ['Date of Transfer:', property_data['transfer_date']],
        ['Purchase Price:', f"${property_data['purchase_price']:,}"],
        ['Property Type:', property_data['property_type']]
    ]
    
    ownership_table = Table(ownership_data, colWidths=[2*inch, 4*inch])
    ownership_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(ownership_table)
    story.append(Spacer(1, 20))
    
    # Encumbrances
    encumb_title = Paragraph("ENCUMBRANCES AND LIENS", styles['Heading2'])
    story.append(encumb_title)
    
    if property_data.get('encumbrances'):
        for encumbrance in property_data['encumbrances']:
            story.append(Paragraph(f"• {encumbrance}", styles['Normal']))
    else:
        story.append(Paragraph("None recorded as of the date of this deed.", styles['Normal']))
    
    story.append(Spacer(1, 30))
    
    # Certification
    cert_text = """
    This deed has been recorded in the official records of the County Recorder's Office.
    This document certifies the legal ownership of the above-described property.
    """
    cert_para = Paragraph(cert_text, styles['Normal'])
    story.append(cert_para)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_building_permit(filename, permit_data):
    """Create a building permit document"""
    c = canvas.Canvas(filename, pagesize=letter)
    width, height = letter
    
    # Header
    c.setFont("Helvetica-Bold", 16)
    c.drawString(50, height - 50, "CITY BUILDING DEPARTMENT")
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, height - 80, "BUILDING PERMIT")
    
    # Permit number and dates
    c.setFont("Helvetica", 10)
    c.drawString(width - 250, height - 50, f"Permit No: {permit_data['permit_number']}")
    c.drawString(width - 250, height - 70, f"Issue Date: {permit_data['issue_date']}")
    c.drawString(width - 250, height - 90, f"Expiration: {permit_data['expiration_date']}")
    
    # Property information
    y_pos = height - 140
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "PROPERTY INFORMATION")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    property_details = [
        ("Property Address:", permit_data['property_address']),
        ("Parcel Number:", permit_data['parcel_number']),
        ("Zoning:", permit_data['zoning']),
        ("Property Owner:", permit_data['property_owner']),
        ("Owner Phone:", permit_data['owner_phone'])
    ]
    
    for label, value in property_details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Permit details
    y_pos -= 20
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "PERMIT DETAILS")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    permit_details = [
        ("Work Description:", permit_data['work_description']),
        ("Construction Type:", permit_data['construction_type']),
        ("Estimated Cost:", f"${permit_data['estimated_cost']:,}"),
        ("Square Footage:", f"{permit_data['square_footage']} sq ft"),
        ("Number of Stories:", permit_data['stories'])
    ]
    
    for label, value in permit_details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Contractor information
    y_pos -= 20
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "CONTRACTOR INFORMATION")
    
    y_pos -= 30
    c.setFont("Helvetica", 11)
    contractor_details = [
        ("Contractor Name:", permit_data['contractor_name']),
        ("License Number:", permit_data['contractor_license']),
        ("Phone:", permit_data['contractor_phone']),
        ("Address:", permit_data['contractor_address'])
    ]
    
    for label, value in contractor_details:
        c.drawString(50, y_pos, label)
        c.drawString(200, y_pos, value)
        y_pos -= 25
    
    # Approvals section
    y_pos -= 30
    c.setFont("Helvetica-Bold", 12)
    c.drawString(50, y_pos, "APPROVALS REQUIRED")
    
    y_pos -= 25
    c.setFont("Helvetica", 10)
    approvals = permit_data.get('approvals', [])
    for approval in approvals:
        c.drawString(70, y_pos, f"☑ {approval}")
        y_pos -= 20
    
    # Footer
    c.setFont("Helvetica", 8)
    c.drawString(50, 80, "This permit becomes void if work is not commenced within 180 days of issuance.")
    c.drawString(50, 65, "All work must be performed in accordance with approved plans and specifications.")
    c.drawString(50, 50, "This is a sample document for testing purposes only")
    c.drawString(50, 35, "All information contained herein is fictional")
    
    c.save()

def create_fire_safety_certificate(filename, safety_data):
    """Create a fire safety certificate"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("FIRE SAFETY CERTIFICATE", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Certificate info
    cert_info = [
        ['Certificate Number:', safety_data['certificate_number']],
        ['Issue Date:', safety_data['issue_date']],
        ['Expiration Date:', safety_data['expiration_date']],
        ['Issuing Authority:', safety_data['issuing_authority']],
        ['Inspector:', safety_data['inspector_name']]
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
    
    # Property details
    property_title = Paragraph("PROPERTY INFORMATION", styles['Heading2'])
    story.append(property_title)
    
    property_info = [
        ['Property Address:', safety_data['property_address']],
        ['Building Type:', safety_data['building_type']],
        ['Occupancy Type:', safety_data['occupancy_type']],
        ['Total Floor Area:', f"{safety_data['floor_area']} sq ft"],
        ['Number of Floors:', safety_data['number_of_floors']]
    ]
    
    property_table = Table(property_info, colWidths=[2*inch, 4*inch])
    property_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(property_table)
    story.append(Spacer(1, 20))
    
    # Fire safety systems
    systems_title = Paragraph("FIRE SAFETY SYSTEMS INSPECTION", styles['Heading2'])
    story.append(systems_title)
    
    systems_data = [
        ['System/Component', 'Status', 'Last Tested', 'Notes'],
        ['Fire Alarm System', 'PASS', safety_data['alarm_test_date'], 'All zones operational'],
        ['Sprinkler System', 'PASS', safety_data['sprinkler_test_date'], 'Adequate pressure'],
        ['Emergency Exits', 'PASS', safety_data['exit_test_date'], 'Clear and marked'],
        ['Fire Extinguishers', 'PASS', safety_data['extinguisher_test_date'], 'Properly charged'],
        ['Emergency Lighting', 'PASS', safety_data['lighting_test_date'], 'Battery backup OK'],
        ['Fire Doors', 'PASS', safety_data['door_test_date'], 'Self-closing mechanism OK']
    ]
    
    systems_table = Table(systems_data, colWidths=[2*inch, 0.8*inch, 1.2*inch, 2*inch])
    systems_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(systems_table)
    story.append(Spacer(1, 20))
    
    # Certification
    cert_title = Paragraph("CERTIFICATION", styles['Heading2'])
    story.append(cert_title)
    
    cert_text = f"""
    This certifies that the above-described property has been inspected and found to be in 
    compliance with applicable fire safety codes and regulations as of {safety_data['inspection_date']}.
    
    This certificate is valid until {safety_data['expiration_date']} unless revoked or suspended.
    """
    
    cert_para = Paragraph(cert_text, styles['Normal'])
    story.append(cert_para)
    story.append(Spacer(1, 20))
    
    # Signature
    signature_info = [
        ['Fire Marshal Signature:', safety_data['marshal_signature']],
        ['Date Signed:', safety_data['signature_date']],
        ['Badge Number:', safety_data['badge_number']]
    ]
    
    signature_table = Table(signature_info, colWidths=[2*inch, 4*inch])
    signature_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(signature_table)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_property_valuation(filename, valuation_data):
    """Create a property valuation report"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("PROPERTY VALUATION REPORT", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Report details
    report_info = [
        ['Report Number:', valuation_data['report_number']],
        ['Valuation Date:', valuation_data['valuation_date']],
        ['Report Date:', valuation_data['report_date']],
        ['Appraiser:', valuation_data['appraiser_name']],
        ['License Number:', valuation_data['appraiser_license']],
        ['Purpose:', valuation_data['purpose']]
    ]
    
    info_table = Table(report_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Property details
    property_title = Paragraph("PROPERTY DESCRIPTION", styles['Heading2'])
    story.append(property_title)
    
    property_info = [
        ['Property Address:', valuation_data['property_address']],
        ['Legal Description:', valuation_data['legal_description']],
        ['Property Type:', valuation_data['property_type']],
        ['Year Built:', valuation_data['year_built']],
        ['Total Living Area:', f"{valuation_data['living_area']:,} sq ft"],
        ['Lot Size:', f"{valuation_data['lot_size']:,} sq ft"],
        ['Bedrooms:', valuation_data['bedrooms']],
        ['Bathrooms:', valuation_data['bathrooms']]
    ]
    
    property_table = Table(property_info, colWidths=[2*inch, 4*inch])
    property_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(property_table)
    story.append(Spacer(1, 20))
    
    # Valuation approaches
    approaches_title = Paragraph("VALUATION APPROACHES", styles['Heading2'])
    story.append(approaches_title)
    
    approaches_data = [
        ['Approach', 'Value Estimate', 'Weight', 'Weighted Value'],
        ['Sales Comparison', f"${valuation_data['sales_comparison']:,}", '60%', f"${int(valuation_data['sales_comparison'] * 0.6):,}"],
        ['Cost Approach', f"${valuation_data['cost_approach']:,}", '25%', f"${int(valuation_data['cost_approach'] * 0.25):,}"],
        ['Income Approach', f"${valuation_data['income_approach']:,}", '15%', f"${int(valuation_data['income_approach'] * 0.15):,}"],
        ['', '', 'Final Value:', f"${valuation_data['final_value']:,}"]
    ]
    
    approaches_table = Table(approaches_data, colWidths=[2*inch, 1.5*inch, 1*inch, 1.5*inch])
    approaches_table.setStyle(TableStyle([
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
    story.append(approaches_table)
    story.append(Spacer(1, 20))
    
    # Market analysis
    market_title = Paragraph("MARKET ANALYSIS", styles['Heading2'])
    story.append(market_title)
    
    market_text = f"""
    The subject property is located in a {valuation_data['market_conditions']} market area. 
    Recent sales in the neighborhood range from ${valuation_data['low_comp']:,} to ${valuation_data['high_comp']:,}.
    
    Market trends indicate {valuation_data['market_trend']} property values in this area.
    The local real estate market has been {valuation_data['market_activity']} with an average
    days on market of {valuation_data['days_on_market']} days.
    """
    
    market_para = Paragraph(market_text, styles['Normal'])
    story.append(market_para)
    story.append(Spacer(1, 20))
    
    # Certification
    cert_title = Paragraph("APPRAISER CERTIFICATION", styles['Heading2'])
    story.append(cert_title)
    
    cert_text = f"""
    I certify that, to the best of my knowledge and belief, the statements and information in this 
    report are true and correct. I have no present or prospective interest in the property that is 
    the subject of this report.
    
    This appraisal was prepared in accordance with the Uniform Standards of Professional Appraisal Practice.
    """
    
    cert_para = Paragraph(cert_text, styles['Normal'])
    story.append(cert_para)
    
    # Signature
    story.append(Spacer(1, 20))
    signature_text = f"Appraiser Signature: {valuation_data['appraiser_signature']}<br/>Date: {valuation_data['signature_date']}"
    signature_para = Paragraph(signature_text, styles['Normal'])
    story.append(signature_para)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def create_construction_specifications(filename, construction_data):
    """Create construction specifications document"""
    doc = SimpleDocTemplate(filename, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title = Paragraph("CONSTRUCTION SPECIFICATIONS", styles['Title'])
    story.append(title)
    story.append(Spacer(1, 12))
    
    # Project details
    project_info = [
        ['Project Name:', construction_data['project_name']],
        ['Project Address:', construction_data['project_address']],
        ['Architect:', construction_data['architect']],
        ['General Contractor:', construction_data['contractor']],
        ['Project Manager:', construction_data['project_manager']],
        ['Specification Date:', construction_data['spec_date']]
    ]
    
    info_table = Table(project_info, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 20))
    
    # Foundation specifications
    foundation_title = Paragraph("SECTION 1: FOUNDATION", styles['Heading2'])
    story.append(foundation_title)
    
    foundation_specs = [
        ['Component', 'Specification', 'Standard/Code'],
        ['Excavation', 'Machine excavation to 8\' depth', 'ASTM D2488'],
        ['Footings', '24" x 12" reinforced concrete', 'ACI 318'],
        ['Foundation Walls', '8" concrete block, Type N mortar', 'ASTM C90'],
        ['Waterproofing', 'Membrane waterproofing system', 'ASTM D6164'],
        ['Drainage', '4" perforated drain tile', 'ASTM D3034']
    ]
    
    foundation_table = Table(foundation_specs, colWidths=[1.5*inch, 2.5*inch, 2*inch])
    foundation_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(foundation_table)
    story.append(Spacer(1, 20))
    
    # Framing specifications
    framing_title = Paragraph("SECTION 2: FRAMING", styles['Heading2'])
    story.append(framing_title)
    
    framing_specs = [
        ['Component', 'Specification', 'Standard/Code'],
        ['Floor Joists', '2x10 SPF @ 16" O.C.', 'IRC 502'],
        ['Wall Studs', '2x6 SPF @ 16" O.C.', 'IRC 602'],
        ['Roof Rafters', '2x8 SPF @ 16" O.C.', 'IRC 802'],
        ['Sheathing', '7/16" OSB, APA rated', 'APA PRP-108'],
        ['Hardware', 'Simpson Strong-Tie connectors', 'ICC-ES reports']
    ]
    
    framing_table = Table(framing_specs, colWidths=[1.5*inch, 2.5*inch, 2*inch])
    framing_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(framing_table)
    story.append(Spacer(1, 20))
    
    # Fire safety specifications
    fire_safety_title = Paragraph("SECTION 3: FIRE SAFETY SYSTEMS", styles['Heading2'])
    story.append(fire_safety_title)
    
    fire_specs = [
        ['System', 'Specification', 'Standard/Code'],
        ['Fire Alarm', 'Addressable system, 24V DC', 'NFPA 72'],
        ['Sprinkler System', 'Wet pipe system, standard response', 'NFPA 13'],
        ['Fire Extinguishers', '2A:10B:C rated, wall mounted', 'NFPA 10'],
        ['Emergency Exits', 'Illuminated exit signs, LED', 'NFPA 101'],
        ['Fire Doors', '90-minute rated, self-closing', 'NFPA 80']
    ]
    
    fire_table = Table(fire_specs, colWidths=[1.5*inch, 2.5*inch, 2*inch])
    fire_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(fire_table)
    story.append(Spacer(1, 20))
    
    # Quality control
    quality_title = Paragraph("QUALITY CONTROL", styles['Heading2'])
    story.append(quality_title)
    
    quality_text = f"""
    All materials and workmanship shall conform to applicable building codes and standards.
    Regular inspections will be conducted at key milestones:
    
    • Foundation inspection before concrete pour
    • Framing inspection before insulation
    • Electrical rough-in inspection
    • Plumbing rough-in inspection
    • Fire safety systems testing and inspection
    • Final building inspection
    
    All work must be performed by licensed contractors and inspected by certified inspectors.
    """
    
    quality_para = Paragraph(quality_text, styles['Normal'])
    story.append(quality_para)
    
    # Footer
    footer = Paragraph("This is a sample document for testing purposes only. All information is fictional.", 
                      ParagraphStyle('Footer', fontSize=8, textColor=colors.grey))
    story.append(Spacer(1, 30))
    story.append(footer)
    
    doc.build(story)

def generate_fire_insurance_docs():
    """Generate all fire insurance documents"""
    # Sample data
    property_data = {
        'deed_number': 'DEED-2024-789456',
        'recording_date': '2024-02-15',
        'county': 'Cook County, Illinois',
        'legal_description': 'Lot 15, Block 3, Meadowbrook Subdivision, as recorded in Plat Book 45, Page 123',
        'street_address': '789 Maple Drive',
        'city': 'Springfield',
        'state': 'Illinois',
        'zip_code': '62704',
        'parcel_id': 'PIN-456-789-012',
        'lot_size': 8500,
        'current_owner': 'Robert and Linda Wilson',
        'previous_owner': 'Thomas Anderson',
        'transfer_date': '2024-02-10',
        'purchase_price': 485000,
        'property_type': 'Single Family Residence',
        'encumbrances': [
            'Mortgage to First National Bank - $350,000',
            'Utility easement - 10 ft rear yard'
        ]
    }
    
    permit_data = {
        'permit_number': 'BP-2024-5678',
        'issue_date': '2024-06-01',
        'expiration_date': '2025-06-01',
        'property_address': '789 Maple Drive, Springfield, IL 62704',
        'parcel_number': 'PIN-456-789-012',
        'zoning': 'R-1 Single Family Residential',
        'property_owner': 'Robert and Linda Wilson',
        'owner_phone': '(555) 234-5678',
        'work_description': 'Two-story addition with family room and master bedroom',
        'construction_type': 'Type V - Wood Frame',
        'estimated_cost': 85000,
        'square_footage': 750,
        'stories': '2',
        'contractor_name': 'Superior Construction LLC',
        'contractor_license': 'CON-789456',
        'contractor_phone': '(555) 345-6789',
        'contractor_address': '123 Builder Lane, Springfield, IL',
        'approvals': [
            'Building Department Review',
            'Fire Department Review',
            'Electrical Permit',
            'Plumbing Permit',
            'HVAC Permit'
        ]
    }
    
    safety_data = {
        'certificate_number': 'FSC-2024-3456',
        'issue_date': '2024-07-20',
        'expiration_date': '2025-07-20',
        'issuing_authority': 'Springfield Fire Department',
        'inspector_name': 'Captain James Rodriguez',
        'property_address': '789 Maple Drive, Springfield, IL 62704',
        'building_type': 'Single Family Residence',
        'occupancy_type': 'Residential - Single Family',
        'floor_area': 2850,
        'number_of_floors': '2',
        'inspection_date': '2024-07-18',
        'alarm_test_date': '2024-07-18',
        'sprinkler_test_date': 'N/A - Not Required',
        'exit_test_date': '2024-07-18',
        'extinguisher_test_date': '2024-07-18',
        'lighting_test_date': '2024-07-18',
        'door_test_date': '2024-07-18',
        'marshal_signature': 'Captain J. Rodriguez',
        'signature_date': '2024-07-20',
        'badge_number': 'FD-4567'
    }
    
    valuation_data = {
        'report_number': 'APR-2024-7890',
        'valuation_date': '2024-08-01',
        'report_date': '2024-08-05',
        'appraiser_name': 'Michelle Thompson, MAI',
        'appraiser_license': 'CRA-5678',
        'purpose': 'Insurance Coverage Determination',
        'property_address': '789 Maple Drive, Springfield, IL 62704',
        'legal_description': 'Lot 15, Block 3, Meadowbrook Subdivision',
        'property_type': 'Single Family Residence',
        'year_built': '2018',
        'living_area': 2850,
        'lot_size': 8500,
        'bedrooms': '4',
        'bathrooms': '3.5',
        'sales_comparison': 495000,
        'cost_approach': 485000,
        'income_approach': 490000,
        'final_value': 492000,
        'market_conditions': 'stable',
        'low_comp': 450000,
        'high_comp': 525000,
        'market_trend': 'slightly increasing',
        'market_activity': 'moderate',
        'days_on_market': 35,
        'appraiser_signature': 'Michelle Thompson, MAI',
        'signature_date': '2024-08-05'
    }
    
    construction_data = {
        'project_name': 'Wilson Residence Addition',
        'project_address': '789 Maple Drive, Springfield, IL 62704',
        'architect': 'Johnson Architecture & Design',
        'contractor': 'Superior Construction LLC',
        'project_manager': 'David Martinez',
        'spec_date': '2024-05-15'
    }
    
    # Generate documents
    create_property_deed('test-documents/fire-insurance/property_deed.pdf', property_data)
    create_building_permit('test-documents/fire-insurance/building_permit.pdf', permit_data)
    create_fire_safety_certificate('test-documents/fire-insurance/fire_safety_certificate.pdf', safety_data)
    create_property_valuation('test-documents/fire-insurance/property_valuation_report.pdf', valuation_data)
    create_construction_specifications('test-documents/fire-insurance/construction_specifications.pdf', construction_data)

if __name__ == "__main__":
    generate_fire_insurance_docs()
    print("Fire insurance documents generated successfully!")