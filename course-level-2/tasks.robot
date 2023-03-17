*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.
...                 Show model info Button
...                 click and capture the model-info Table content. It has thead and tbody.
...                 Head - select id = head Body - radio required value from 1 to 6
...                 upadte Legs and Addrress
...                 submit id=order button

Library             RPA.Browser.Selenium    auto_close=${True}
Library             RPA.Excel.Files
Library             RPA.HTTP
Library             RPA.Desktop
Library             RPA.Tables
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault
Library             RPA.PDF
Library             Screenshot
Library             OperatingSystem
Library             RPA.Archive


*** Variables ***
${constitution_model_ok_button}         CSS:#root > div > div.modal > div > div > div > div > div > button.btn.btn-dark
${order_page_head_select}               id=head
${order_page_body_checkbox_prefix}      id=id-body-
${order_page_legs_part_number_field}    //input[@placeholder='Enter the part number for the legs']
${order_page_address_field}             id=address

${order_page_preview_btn}               xpath://*[@id='preview']    #id=preview
${order_page_order_btn}                 xpath://*[@id='order']    #id=order

${order_page_robot_preview_image}       xpath://*[@id='robot-preview-image']
${order_page_order_another_btn}         xpath://*[@id='order-another']    #id=order-another

${order_page_receipt_alert}             xpath://*[@id='receipt']    # id=receipt
${order_submit_danger_alert}            xpath://*[@id="root"]/div/div[1]/div/div[1]/div

${out_dir}                              ${CURDIR}${/}output
${screenshot_dir}                       ${CURDIR}${/}screenshots
${receipt_dir}                          ${CURDIR}${/}receipts

${GLOBAL_RETRY_AMOUNT}                  5x
${GLOBAL_RETRY_INTERVAL}                1s


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Clear folders

    Open order page

    ${orders} =    Get orders
    FOR    ${row}    IN    @{orders}
        Close the constitution modal
        Build Robot    ${row}
        # Preview Robot
        Wait Until Keyword Succeeds    ${GLOBAL_RETRY_AMOUNT}    ${GLOBAL_RETRY_INTERVAL}    Preview Robot
        Sleep    2sec
        # Submit Order
        Wait Until Keyword Succeeds    ${GLOBAL_RETRY_AMOUNT}    ${GLOBAL_RETRY_INTERVAL}    Submit Order
        Sleep    2sec
        FOR    ${i}    IN RANGE    ${100}
            ${alert} =    Is Element Visible    //div[@class="alert alert-danger"]
            IF    '${alert}'=='True'    Click Button    //button[@id="order"]
            IF    '${alert}'=='False'                BREAK
        END

        # Capture Receipts into pdf    ${row}[Order number]

        ${screenshot} =    Take screenshot of the robot    ${row}[Order number]
        Log    ${row}[Order number]' Robot Ordered'
        Create receipt PDF with robot preview image    ${row}[Order number]    ${screenshot}

        Wait Until Keyword Succeeds    ${GLOBAL_RETRY_AMOUNT}    ${GLOBAL_RETRY_INTERVAL}    Order another Robot
    END

    Create ZIP file of all receipts

    Close Browser and cleanup


*** Keywords ***
 Open order page
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order
    Maximize Browser Window

Get orders
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True
    ${orders} =    Read table from CSV    orders.csv
    RETURN    ${orders}

Close the constitution modal
    Click Button    ${constitution_model_ok_button}

Build Robot
    [Arguments]    ${order_record}
    # Fill the order page
    #    Order number,Head,Body,Legs,Address
    Select From List By Value    ${order_page_head_select}    ${order_record}[Head]
    Click Element    ${order_page_body_checkbox_prefix}${order_record}[Body]
    Input Text    ${order_page_legs_part_number_field}    ${order_record}[Legs]
    Input Text    ${order_page_address_field}    ${order_record}[Address]

    # Submit order

Preview Robot
    # Click Preview button
    Wait Until Keyword Succeeds
    ...    ${GLOBAL_RETRY_AMOUNT}
    ...    ${GLOBAL_RETRY_INTERVAL}
    ...    Click Button
    ...    ${order_page_preview_btn}

    # Click Button    ${order_page_preview_btn}

Submit Order
    Click Button    ${order_page_order_btn}

Order another Robot
    Wait And Click Button    ${order_page_order_another_btn}
    # Click Button    ${order_page_order_another_btn}

#robot-preview-image

Take screenshot of the robot
    [Arguments]    ${order_number}
    Set Local Variable    ${file_path}    ${screenshot_dir}${/}robot_preview_image_${order_number}.png
    ${robot_img} =    Screenshot    ${order_page_robot_preview_image}    ${file_path}
    RETURN    ${robot_img}

    Screenshot

Create receipt PDF with robot preview image
    [Arguments]    ${order_number}    ${robot_order_img}
    ${receipt_pdf} =    Store order receipt as PDF file    ${order_number}

    # Embed robot preview screenshot to receipt PDF file
    # ...    ${robot_order_img}
    # ...    ${receipt_dir}${/}receipt_${order_number}.pdf

Store order receipt as PDF file
    [Arguments]    ${order_number}
    ${receipt_html} =    Get Element Attribute    ${order_page_receipt_alert}    outerHTML
    Set Local Variable    ${file_path}    ${receipt_dir}${/}receipt_${order_number}.pdf
    Html To Pdf    ${receipt_html}    ${file_path}
    RETURN    ${file_path}

Embed robot preview screenshot to receipt PDF file
    [Arguments]    ${img}    ${pdf_file}

    Open Pdf    ${pdf_file}

    @{image_files} =    Create List    ${img}:align=center
    Add Files To PDF    ${image_files}    ${pdf_file}    True
    Close Pdf    ${pdf_file}

Clear folders
    Create Directory    ${out_dir}
    Create Directory    ${screenshot_dir}
    Create Directory    ${receipt_dir}

    Empty Directory    ${out_dir}
    Empty Directory    ${screenshot_dir}
    Empty Directory    ${receipt_dir}

Create ZIP file of all receipts
    ${zip_file_name} =    Set Variable    ${out_dir}${/}all_receipts.zip
    Archive Folder With Zip    ${receipt_dir}    ${zip_file_name}

Close Browser and cleanup
    Close Browser
