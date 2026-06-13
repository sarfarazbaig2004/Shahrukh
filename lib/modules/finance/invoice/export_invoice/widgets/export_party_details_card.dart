// lib/modules/finance/invoice/widgets/export_party_details_card.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';

class ExportPartyDetailsCard extends StatefulWidget {
  final String title;

  /// BILL TO
  final TextEditingController billName;
  final TextEditingController billAddress;
  final TextEditingController billCountry;
  final TextEditingController billContact;
  final TextEditingController billEmail;
  final TextEditingController billPhone;

  /// SHIP TO
  final TextEditingController shipName;
  final TextEditingController shipAddress;
  final TextEditingController shipCountry;
  final TextEditingController shipContact;
  final TextEditingController shipEmail;
  final TextEditingController shipPhone;

  const ExportPartyDetailsCard({
    super.key,
    required this.title,
    required this.billName,
    required this.billAddress,
    required this.billCountry,
    required this.billContact,
    required this.billEmail,
    required this.billPhone,
    required this.shipName,
    required this.shipAddress,
    required this.shipCountry,
    required this.shipContact,
    required this.shipEmail,
    required this.shipPhone,
  });

  @override
  State<ExportPartyDetailsCard> createState() =>
      _ExportPartyDetailsCardState();
}

class _ExportPartyDetailsCardState
    extends State<ExportPartyDetailsCard> {
  bool same = false;

  void _sync() {
    if (!same) return;

    widget.shipName.value = widget.shipName.value.copyWith(
      text: widget.billName.text,
      selection: TextSelection.collapsed(offset: widget.billName.text.length),
    );
    widget.shipAddress.value = widget.shipAddress.value.copyWith(
      text: widget.billAddress.text,
      selection: TextSelection.collapsed(offset: widget.billAddress.text.length),
    );
    widget.shipCountry.value = widget.shipCountry.value.copyWith(
      text: widget.billCountry.text,
      selection: TextSelection.collapsed(offset: widget.billCountry.text.length),
    );
    widget.shipContact.value = widget.shipContact.value.copyWith(
      text: widget.billContact.text,
      selection: TextSelection.collapsed(offset: widget.billContact.text.length),
    );
    widget.shipEmail.value = widget.shipEmail.value.copyWith(
      text: widget.billEmail.text,
      selection: TextSelection.collapsed(offset: widget.billEmail.text.length),
    );
    widget.shipPhone.value = widget.shipPhone.value.copyWith(
      text: widget.billPhone.text,
      selection: TextSelection.collapsed(offset: widget.billPhone.text.length),
    );
  }

  void _clearShipFields() {
    widget.shipName.clear();
    widget.shipAddress.clear();
    widget.shipCountry.clear();
    widget.shipContact.clear();
    widget.shipEmail.clear();
    widget.shipPhone.clear();
  }

  @override
  void initState() {
    super.initState();

    widget.billName.addListener(_sync);
    widget.billAddress.addListener(_sync);
    widget.billCountry.addListener(_sync);
    widget.billContact.addListener(_sync);
    widget.billEmail.addListener(_sync);
    widget.billPhone.addListener(_sync);
  }

  @override
  void dispose() {
    widget.billName.removeListener(_sync);
    widget.billAddress.removeListener(_sync);
    widget.billCountry.removeListener(_sync);
    widget.billContact.removeListener(_sync);
    widget.billEmail.removeListener(_sync);
    widget.billPhone.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              const Icon(Icons.business, color: zBlue),
              const SizedBox(width: 10),
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Row(
                children: [
                  Checkbox(
                    value: same,
                    onChanged: (v) {
                      setState(() {
                        same = v!;
                        if (same) {
                          _sync();
                        } else {
                          _clearShipFields();
                        }
                      });
                    },
                  ),
                  const Text('Ship same as Bill'),
                ],
              )
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _card('Bill To', true)),
              const SizedBox(width: 20),
              Expanded(child: _card('Ship To', false)),
            ],
          )
        ],
      ),
    );
  }

  Widget _card(String title, bool isBill) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: same && !isBill ? Colors.grey.shade100 : Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),

          _field('Company Name',
              isBill ? widget.billName : widget.shipName,
              readOnly: isBill ? false : same),

          const SizedBox(height: 10),

          _field('Address',
              isBill ? widget.billAddress : widget.shipAddress,
              maxLines: 2,
              readOnly: isBill ? false : same),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _field('Country',
                    isBill ? widget.billCountry : widget.shipCountry,
                    readOnly: isBill ? false : same),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field('Contact Person',
                    isBill ? widget.billContact : widget.shipContact,
                    readOnly: isBill ? false : same),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _field('Email',
                    isBill ? widget.billEmail : widget.shipEmail,
                    readOnly: isBill ? false : same),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field('Phone',
                    isBill ? widget.billPhone : widget.shipPhone,
                    readOnly: isBill ? false : same),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, bool readOnly = false}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.transparent,
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}