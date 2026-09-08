import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const sections = <Map<String, String>>[
    {'title':'Data Privacy Notice','body':'This Notice outlines Sprout’s commitment to safeguarding and protecting user privacy. It governs the collection, processing, and disclosure of user data obtained through Sprout’s website, mobile application, and offline sources. By accessing or using the website or app, you consent to the practices described in this Notice.'},
    {'title':'Data Protection','body':'Sprout is dedicated to maintaining data protection in accordance with applicable data protection laws and regulations. Sprout does not share personal information with third parties or individuals unless required by a court order or subpoena. Prior to exceptional disclosure, Sprout will diligently seek your explicit consent.'},
    {'title':'Information Collection and Purpose','body':'Sprout may collect and process: Name; Email address; Phone number; Street address; City; District; State; PIN code; and Country. This information is used for creation of your user profile on the App.'},
    {'title':'Photos, Videos and Files','body':'With your consent, Sprout may request access to upload photos, videos, and other file formats for profile customization, post creation, and messaging functionalities.'},
    {'title':'Analytics and Communications','body':'Sprout may employ tracking tools such as Google Analytics to understand App and website usage. With your consent, contact details may be used to communicate special promotions, new features, or products. Essential account-related SMS or emails may also be sent.'},
    {'title':'Contacts and Microphone','body':'If you permit access to contacts, you can connect and interact with existing contacts and friends within the App. If consent is granted, Sprout may request microphone access for audio/video recording or participation in live App meetings.'},
    {'title':'Promotional Calls','body':'By submitting a web form, you explicitly consent to receive promotional calls from third-party platforms on the number you provided.'},
    {'title':'Account and Personal Data Deletion','body':'You retain the right to delete your personal data and close your account at any time. To exercise this right: log into your account → navigate to Profile → access Settings → select Delete Account.'},
    {'title':'Jurisdiction','body':'Your visit to the Sprout website or App and privacy-related disputes are governed by this Notice and the website/App terms of use. Disputes under this Notice are subject to the laws of India.'},
    {'title':'Contact Information','body':'For privacy inquiries or concerns: mahesh@akshatmedia.in'},
    {'title':'Updated Date','body':'This Data Privacy Notice was last updated in September 2026. Sprout may periodically revise its privacy practices and will publish an updated copy on its website.'},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundDark,
    appBar: AppBar(
      backgroundColor: AppTheme.backgroundDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        color: AppTheme.textPrimary,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text('Privacy Policy', style: GoogleFonts.manrope(
        color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text('Sprout’s Privacy Policy', style: GoogleFonts.manrope(
          color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('This Privacy Policy applies to your use of the Sprout mobile application and explains how Sprout collects, uses, protects, and handles information provided through the App.',
          style: GoogleFonts.manrope(color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
        const SizedBox(height: 24),
        for (final s in sections) ...[
          Text(s['title']!, style: GoogleFonts.manrope(
            color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(s['body']!, style: GoogleFonts.manrope(
            color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
          const SizedBox(height: 22),
        ],
      ],
    ),
  );
}
