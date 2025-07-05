import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WithdrawalScreen extends StatefulWidget {
  final double currentBalance;
  const WithdrawalScreen({super.key, required this.currentBalance});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();

  String? _selectedBank;
  bool _isOtherBank = false;
  final List<String> _malaysianBanks = [
    'Maybank',
    'CIMB Bank',
    'Public Bank Berhad',
    'RHB Bank',
    'Hong Leong Bank',
    'AmBank',
    'UOB Malaysia',
    'Bank Rakyat',
    'OCBC Bank Malaysia',
    'HSBC Bank Malaysia',
    'Bank Islam Malaysia',
    'Affin Bank',
    'Standard Chartered Malaysia',
    'Other',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _submitWithdrawalRequest() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to make a withdrawal.')),
        );
        return;
      }

      final String bankName = _isOtherBank ? _bankNameController.text : _selectedBank!;

      // In a real app, this is where you would integrate with a payment gateway API.
      // For this example, we will just show a success message and pop the screen.
      await FirebaseFirestore.instance.collection('withdrawals').add({
        'userId': user.uid,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'bankName': bankName,
        'accountHolderName': _accountHolderController.text,
        'accountNumber': _accountNumberController.text,
        'status': 'pending', // Initial status
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted for processing.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request Withdrawal', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Balance: RM ${widget.currentBalance.toStringAsFixed(2)}',
                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Withdrawal Amount (RM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Please enter a valid number';
                  }
                  if (amount <= 0) {
                    return 'Amount must be greater than zero';
                  }
                  if (amount > widget.currentBalance) {
                    return 'Amount cannot exceed your current balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Bank Account Details', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                value: _selectedBank,
                items: _malaysianBanks.map((String bank) {
                  return DropdownMenuItem<String>(
                    value: bank,
                    child: Text(bank),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedBank = newValue;
                    _isOtherBank = (newValue == 'Other');
                  });
                },
                validator: (value) => value == null ? 'Please select a bank' : null,
              ),
              if (_isOtherBank)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextFormField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Please specify other bank',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_isOtherBank && (value == null || value.isEmpty)) {
                        return 'Please specify your bank name';
                      }
                      return null;
                    },
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountHolderController,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter the account holder name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bank Account Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter an account number' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitWithdrawalRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Withdrawal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 