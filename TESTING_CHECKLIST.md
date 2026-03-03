# Testing Checklist - POS & ERP System

## ✅ Authentication
- [ ] Login with admin/admin123
- [ ] Login with cashier/cashier123
- [ ] Login with wrong credentials (should fail)
- [ ] Logout
- [ ] Token persistence (close app, reopen - should stay logged in)

## ✅ Dashboard
- [ ] View sales summary
- [ ] View today's sales
- [ ] View total orders
- [ ] View statistics cards
- [ ] Click on cards to navigate
- [ ] Refresh data

## ✅ Product Management
- [ ] View product list
- [ ] Search products
- [ ] Add new product
- [ ] Edit product
- [ ] Delete product
- [ ] Form validation works
- [ ] Price levels display correctly

## ✅ Customer Management
- [ ] View customer list
- [ ] Search customers
- [ ] Add new customer
- [ ] Edit customer
- [ ] Delete customer
- [ ] Credit limit/days save correctly
- [ ] Member number works

## ✅ POS System
- [ ] View product grid
- [ ] Search products
- [ ] Add product to cart
- [ ] Increase/decrease quantity
- [ ] Remove item from cart
- [ ] Select customer
- [ ] Apply discount (% and amount)
- [ ] Hold order
- [ ] Recall held order
- [ ] Multiple held orders
- [ ] Cart totals calculate correctly

## ✅ Payment
- [ ] Payment screen opens
- [ ] Cash payment works
- [ ] Card payment works
- [ ] Transfer payment works
- [ ] Change calculation correct
- [ ] Quick amount buttons work
- [ ] Cannot pay with insufficient cash
- [ ] Order saves to database

## ✅ Sales History
- [ ] View order list
- [ ] Click to view order details
- [ ] Order items display correctly
- [ ] Payment info shows
- [ ] Receipt preview works
- [ ] Print button exists

## ✅ Inventory Management
- [ ] View stock balance
- [ ] Search stock
- [ ] Stock In (add stock)
- [ ] Stock Out (remove stock)
- [ ] Stock Adjust
- [ ] Stock Transfer between warehouses
- [ ] Low stock alert shows
- [ ] Movement history displays
- [ ] Auto stock deduction on sale

## ✅ Reports
- [ ] Sales summary displays
- [ ] Top products show correctly
- [ ] Top customers show correctly
- [ ] Sales chart displays
- [ ] Daily sales data accurate
- [ ] Export to CSV works
- [ ] Refresh updates data

## ✅ Settings
- [ ] Company info saves
- [ ] VAT settings work
- [ ] Stock alert settings work
- [ ] Keyboard shortcuts info displays

## ✅ Keyboard Shortcuts
- [ ] F1 - Opens POS
- [ ] F2 - Opens Products
- [ ] F3 - Opens Customers
- [ ] F4 - Opens Sales History
- [ ] F6 - Opens Inventory
- [ ] F7 - Opens Reports
- [ ] F10 - Opens Dashboard

## ✅ Performance
- [ ] App starts in < 3 seconds
- [ ] Navigation is smooth
- [ ] No lag when scrolling lists
- [ ] Images load properly
- [ ] Search is responsive
- [ ] Database queries are fast

## ✅ Error Handling
- [ ] Network errors show properly
- [ ] Form validation works
- [ ] Error messages are clear
- [ ] App doesn't crash on errors
- [ ] Loading states display

## ✅ UI/UX
- [ ] All text is readable
- [ ] Colors are consistent
- [ ] Icons are appropriate
- [ ] Buttons are clear
- [ ] Forms are user-friendly
- [ ] Responsive on different screen sizes