import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import * as XLSX from "xlsx";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {createHash, randomBytes, timingSafeEqual} from "crypto";

admin.initializeApp();
const db = admin.firestore();

/* ===================== SECRETS ===================== */

const gmailUser = defineSecret("QUIK_GMAIL_USER");
const gmailPass = defineSecret("QUIK_GMAIL_APP_PASSWORD");

/* ===================== HELPERS ===================== */

/**
 * Generates a 6-digit OTP.
 * @return {string}
 */
function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Builds the Gmail transporter for OTP emails.
 * @return {nodemailer.Transporter}
 */
function buildTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailUser.value(),
      pass: gmailPass.value(),
    },
  });
}

/**
 * Deletes sensitive fields left by older OTP draft implementations.
 * @return {Record<string, FirebaseFirestore.FieldValue>}
 */
function legacyRequestSecretDeletes() {
  return {
    password: admin.firestore.FieldValue.delete(),
  };
}

/**
 * Reads a string field from callable data safely.
 * @param {unknown} value source value
 * @return {string}
 */
function callableString(value: unknown): string {
  return (value ?? "").toString().trim();
}

/**
 * Returns true when a value is blank-like.
 * @param {unknown} value source value
 * @return {boolean}
 */
function isBlankValue(value: unknown): boolean {
  if (value === null || value === undefined) return true;
  return value.toString().trim().length === 0;
}

/**
 * Normalizes a free-form id into a Firestore-safe slug.
 * @param {string} value source text
 * @return {string}
 */
function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 120);
}

/**
 * Converts a value into finite number.
 * @param {unknown} value source value
 * @return {number}
 */
function safeNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const normalized = (value ?? "").toString().replace(/,/g, "").trim();
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : 0;
}

/**
 * Resolves a user's access to a tenant for sensitive callable operations.
 * @param {string} uid authenticated user id
 * @param {string} tenantId target tenant id
 * @return {Promise<void>}
 */
async function assertTenantAccess(
  uid: string,
  tenantId: string,
): Promise<void> {
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("permission-denied", "User profile not found.");
  }

  const userData = userSnap.data() || {};
  const primaryCompanyId = callableString(userData.companyId);
  const companyIds = Array.isArray(userData.companyIds) ?
    userData.companyIds.map((value: unknown) => callableString(value)) :
    [];
  const memberships = userData.memberships &&
    typeof userData.memberships === "object" ?
    Object.keys(userData.memberships) :
    [];
  const isPlatformAdmin = userData.isPlatformAdmin === true;

  if (
    isPlatformAdmin ||
    primaryCompanyId === tenantId ||
    companyIds.includes(tenantId) ||
    memberships.includes(tenantId)
  ) {
    return;
  }

  throw new HttpsError(
    "permission-denied",
    "You do not have access to import stock for this company.",
  );
}

/**
 * Deletes all docs in a subcollection under a parent document.
 * @param {FirebaseFirestore.DocumentReference} parentRef parent doc ref
 * @param {string} subcollectionName subcollection name
 * @return {Promise<void>}
 */
async function clearSubcollection(
  parentRef: FirebaseFirestore.DocumentReference,
  subcollectionName: string,
): Promise<void> {
  const docs = await parentRef.collection(subcollectionName).get();
  if (docs.empty) return;

  const batchSize = 400;
  for (let index = 0; index < docs.docs.length; index += batchSize) {
    const chunk = docs.docs.slice(index, index + batchSize);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

type FabricationStockImportLine = {
  itemId: string;
  lineId: string;
  lineNo: number;
  materialDescription: string;
  grade: string;
  lengthMm: number;
  unitWeightKgPerM: number;
  openingStockNos: number;
  openingStockKg: number;
  inwardStockKg: number;
  currentOpeningStockKg: number;
  totalIssuedKg: number;
  closingStockKg: number;
  remarks: string;
  uom: string;
};

/**
 * Parses Aman-style raw material stock workbook.
 * @param {Buffer} buffer xlsx buffer
 * @param {string} fallbackFileName uploaded file name
 * @return {{
 *   sheetName: string,
 *   monthLabel: string,
 *   monthKey: string,
 *   lines: FabricationStockImportLine[],
 * }}
 */
function parseFabricationRawMaterialWorkbook(
  buffer: Buffer,
  fallbackFileName: string,
): {
  sheetName: string;
  monthLabel: string;
  monthKey: string;
  lines: FabricationStockImportLine[];
} {
  const workbook = XLSX.read(buffer, {type: "buffer"});
  const sheetName = workbook.SheetNames[0];
  if (!sheetName) {
    throw new HttpsError("failed-precondition", "Workbook has no sheets.");
  }

  const worksheet = workbook.Sheets[sheetName];
  const rows = XLSX.utils.sheet_to_json<(string | number)[]>(worksheet, {
    header: 1,
    defval: "",
    raw: true,
  });

  const titleRow = rows.find((row) =>
    row.some((cell) =>
      cell.toString().toLowerCase().includes("raw materials stock"),
    ),
  ) || [];

  const monthLabelMatch = titleRow
    .map((cell) => cell.toString())
    .join(" ")
    .match(/\(([^)]+)\)/);
  const monthLabel = monthLabelMatch?.[1]?.trim() || "Imported Stock";

  const monthKeyMatch = monthLabel.match(
    /(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-\s](\d{2,4})/i,
  );
  const monthMap: Record<string, string> = {
    jan: "01",
    feb: "02",
    mar: "03",
    apr: "04",
    may: "05",
    jun: "06",
    jul: "07",
    aug: "08",
    sep: "09",
    oct: "10",
    nov: "11",
    dec: "12",
  };
  const matchedYear = monthKeyMatch?.[2] ?? "";
  const normalizedYear = matchedYear.length === 2 ?
    matchedYear :
    matchedYear.slice(-2);
  const matchedMonthKey = monthKeyMatch ?
    monthMap[monthKeyMatch[1].slice(0, 3).toLowerCase()] :
    "";
  const monthKey = monthKeyMatch ?
    `20${normalizedYear}-${matchedMonthKey}` :
    slugify(monthLabel || fallbackFileName || "imported_stock");

  const headerRowIndex = rows.findIndex((row) =>
    row.some((cell) =>
      cell.toString().toLowerCase().includes("material description"),
    ),
  );
  if (headerRowIndex < 0) {
    throw new HttpsError(
      "failed-precondition",
      "Could not find the stock header row in this workbook.",
    );
  }

  const lines: FabricationStockImportLine[] = [];
  for (let i = headerRowIndex + 1; i < rows.length; i++) {
    const row = rows[i] || [];
    const serial = row[0];
    const materialDescription = callableString(row[1]);
    const grade = callableString(row[2]);

    const rowLooksEmpty = row.every((cell) => isBlankValue(cell));
    if (rowLooksEmpty) continue;

    const serialNumber = safeNumber(serial);
    if (!materialDescription || serialNumber <= 0) {
      continue;
    }

    const rawLength = safeNumber(row[3]);
    const lengthMm = rawLength > 0 && rawLength <= 30 ?
      rawLength * 1000 :
      rawLength;
    const unitWeightKgPerM = safeNumber(row[4]);
    const openingStockNos = safeNumber(row[5]);
    const openingStockKg = safeNumber(row[6]);
    const inwardStockKg = safeNumber(row[7]);
    const currentOpeningStockKg = safeNumber(row[8]);
    const totalIssuedKg = safeNumber(row[9]);
    const closingStockKg = safeNumber(row[10]);
    const remarks = callableString(row[11]);

    const itemId = slugify(
      `${materialDescription}_${grade}_${lengthMm || rawLength}`,
    ) || `rm_${serialNumber}`;

    lines.push({
      itemId,
      lineId: itemId,
      lineNo: serialNumber,
      materialDescription,
      grade,
      lengthMm,
      unitWeightKgPerM,
      openingStockNos,
      openingStockKg,
      inwardStockKg,
      currentOpeningStockKg,
      totalIssuedKg,
      closingStockKg,
      remarks,
      uom: "Kg",
    });
  }

  if (!lines.length) {
    throw new HttpsError(
      "failed-precondition",
      "The workbook was read, but no stock lines were found.",
    );
  }

  return {
    sheetName,
    monthLabel,
    monthKey,
    lines,
  };
}

/**
 * Gets an OAuth access token for Google REST APIs.
 * @return {Promise<string>}
 */
async function getGoogleAccessToken(): Promise<string> {
  const credential = admin.app().options.credential as unknown as {
    getAccessToken?: () => Promise<{access_token?: string}>;
  };

  if (!credential.getAccessToken) {
    throw new HttpsError(
      "failed-precondition",
      "Firebase Admin credential cannot create an access token.",
    );
  }

  const token = await credential.getAccessToken();
  if (!token.access_token) {
    throw new HttpsError(
      "failed-precondition",
      "Google access token was not returned.",
    );
  }

  return token.access_token;
}

/**
 * Extracts useful fabrication inquiry fields from OCR text.
 * @param {string} rawText OCR full text
 * @return {Record<string, string>}
 */
function parseFabricationInquiryText(rawText: string): Record<string, string> {
  const normalized = rawText.replace(/\r/g, "\n");
  const lines = normalized
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const joined = lines.join("\n");

  const valueAfterLabel = (label: RegExp): string => {
    for (const line of lines) {
      const match = line.match(label);
      if (match?.[1]) {
        return match[1].replace(/\s{2,}.*/, "").trim();
      }
    }
    return "";
  };

  const uniqueMatches = (pattern: RegExp): string[] => {
    const matches = new Set<string>();
    for (const match of joined.matchAll(pattern)) {
      if (match[0]) {
        matches.add(match[0].replace(/\s+/g, "").toUpperCase());
      }
    }
    return [...matches];
  };

  const clientName = valueAfterLabel(/CLIENT\s*NAME\s*[:-]?\s*(.+)$/i);
  const projectCapacity = valueAfterLabel(
    /PROJECT\s*CAPACITY\s*[:-]?\s*([^\n(]+)/i,
  );
  const moduleDataSheet = valueAfterLabel(
    /MODULE\s*DATA\s*SHEET\s*[:-]?\s*(.+)$/i,
  );
  const moduleCount = valueAfterLabel(
    /Nos\.?\s*of\s*Module\s*[:-]?\s*(.+)$/i,
  );
  const boqNo = valueAfterLabel(/BOQ\s*No\.?\s*[:-]?\s*(.+)$/i);
  const date = valueAfterLabel(/DATE\s*[:-]?\s*(.+)$/i) ||
    (joined.match(/\b\d{2}[-/]\d{2}[-/]\d{4}\b/)?.[0] ?? "");
  const tableConfigurations = uniqueMatches(/\b\d+\s*P\s*X\s*\d+\b/gi);
  const moduleWp = joined.match(/\b(\d{3,4})\s*W[Pp]\b/)?.[1] ?? "";
  const depthFromPhrase = joined.match(/(\d{3,5})\s*mm\s+for\s+depth/i)?.[1] ??
    joined.match(/depth[^\d]{0,20}(\d{3,5})\s*mm/i)?.[1] ??
    "";

  return {
    clientName,
    projectCapacityKWp: projectCapacity.replace(/kwp?/ig, "").trim(),
    moduleWp,
    moduleDataSheet,
    moduleCount,
    tableConfiguration: tableConfigurations.join(", "),
    pileDepth: depthFromPhrase ? `${depthFromPhrase} MM` : "",
    boqReference: [boqNo, date].filter((value) => value).join(" • "),
    sourceTextPreview: joined.slice(0, 1800),
  };
}

/* =========================================================
   ============= FABRICATION DOCUMENT EXTRACTION ============
   ========================================================= */

export const extractFabricationInquiryFromDocument = onCall(
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const companyId = callableString(request.data?.companyId);
    const storagePath = callableString(request.data?.storagePath);
    const contentType = callableString(request.data?.contentType);

    if (!companyId || !storagePath) {
      throw new HttpsError(
        "invalid-argument",
        "companyId and storagePath are required.",
      );
    }

    const allowedPrefix = `tenant_inquiries/${companyId}/source_documents/`;
    if (!storagePath.startsWith(allowedPrefix)) {
      throw new HttpsError(
        "permission-denied",
        "Document does not belong to this company inquiry path.",
      );
    }

    if (contentType && !contentType.startsWith("image/")) {
      throw new HttpsError(
        "failed-precondition",
        "Auto extraction currently supports JPG and PNG images. " +
          "PDF/Excel are stored as attachments for manual review.",
      );
    }

    const token = await getGoogleAccessToken();
    const bucketName = admin.storage().bucket().name;
    const imageUri = `gs://${bucketName}/${storagePath}`;

    const response = await fetch(
      "https://vision.googleapis.com/v1/images:annotate",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          requests: [
            {
              image: {source: {imageUri}},
              features: [{type: "DOCUMENT_TEXT_DETECTION"}],
            },
          ],
        }),
      },
    );

    if (!response.ok) {
      const errorText = await response.text();
      throw new HttpsError(
        "internal",
        `Vision OCR failed: ${errorText}`,
      );
    }

    const payload = await response.json() as {
      responses?: Array<{
        fullTextAnnotation?: {text?: string};
        textAnnotations?: Array<{description?: string}>;
        error?: {message?: string};
      }>;
    };

    const firstResponse = payload.responses?.[0];
    if (firstResponse?.error?.message) {
      throw new HttpsError("internal", firstResponse.error.message);
    }

    const rawText = firstResponse?.fullTextAnnotation?.text ??
      firstResponse?.textAnnotations?.[0]?.description ??
      "";

    if (!rawText.trim()) {
      throw new HttpsError(
        "not-found",
        "No readable text found in the uploaded image.",
      );
    }

    return {
      rawText,
      fields: parseFabricationInquiryText(rawText),
    };
  },
);

/* =========================================================
   ========== FABRICATION RAW MATERIAL IMPORT ==============
   ========================================================= */

export const importFabricationRawMaterialStockSheet = onCall(
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const tenantId = callableString(request.data?.tenantId);
    const storagePath = callableString(request.data?.storagePath);
    const fileName = callableString(request.data?.fileName);

    if (!tenantId || !storagePath) {
      throw new HttpsError(
        "invalid-argument",
        "tenantId and storagePath are required.",
      );
    }

    await assertTenantAccess(uid, tenantId);

    const profileSnap = await db
      .collection("tenants")
      .doc(tenantId)
      .collection("inventory_config")
      .doc("profile")
      .get();

    const profileType = callableString(profileSnap.data()?.profileType);
    if (profileType !== "fabrication_inventory") {
      throw new HttpsError(
        "failed-precondition",
        "This importer is available only for fabrication inventory tenants.",
      );
    }

    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError("not-found", "Uploaded stock sheet not found.");
    }

    const [buffer] = await file.download();
    const parsed = parseFabricationRawMaterialWorkbook(buffer, fileName);

    const snapshotRef = db
      .collection("tenants")
      .doc(tenantId)
      .collection("raw_material_stock_snapshots")
      .doc(parsed.monthKey);

    await snapshotRef.set({
      snapshotId: parsed.monthKey,
      monthKey: parsed.monthKey,
      monthLabel: parsed.monthLabel,
      sourceFileName: fileName,
      sourceStoragePath: storagePath,
      sheetName: parsed.sheetName,
      status: "imported",
      importedBy: uid,
      importedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    await clearSubcollection(snapshotRef, "lines");

    const lineChunks: FabricationStockImportLine[][] = [];
    for (let i = 0; i < parsed.lines.length; i += 350) {
      lineChunks.push(parsed.lines.slice(i, i + 350));
    }

    for (const chunk of lineChunks) {
      const batch = db.batch();
      for (const line of chunk) {
        batch.set(snapshotRef.collection("lines").doc(line.lineId), {
          lineId: line.lineId,
          lineNo: line.lineNo,
          itemId: line.itemId,
          materialDescription: line.materialDescription,
          grade: line.grade,
          lengthMm: line.lengthMm,
          unitWeightKgPerM: line.unitWeightKgPerM,
          openingStockNos: line.openingStockNos,
          openingStockKg: line.openingStockKg,
          inwardStockKg: line.inwardStockKg,
          currentOpeningStockKg: line.currentOpeningStockKg,
          totalIssuedKg: line.totalIssuedKg,
          closingStockKg: line.closingStockKg,
          remarks: line.remarks,
          uom: line.uom,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        batch.set(
          db.collection("tenants")
            .doc(tenantId)
            .collection("raw_material_items")
            .doc(line.itemId),
          {
            itemId: line.itemId,
            itemCode: line.itemId.toUpperCase(),
            materialDescription: line.materialDescription,
            grade: line.grade,
            lengthMm: line.lengthMm,
            unitWeightKgPerM: line.unitWeightKgPerM,
            uom: line.uom,
            isActive: true,
            source: "snapshot_import",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );

        batch.set(
          db.collection("tenants")
            .doc(tenantId)
            .collection("raw_material_stock_summary")
            .doc(line.itemId),
          {
            itemId: line.itemId,
            materialDescription: line.materialDescription,
            grade: line.grade,
            lengthMm: line.lengthMm,
            unitWeightKgPerM: line.unitWeightKgPerM,
            openingStockNos: line.openingStockNos,
            openingStockKg: line.openingStockKg,
            inwardStockKg: line.inwardStockKg,
            currentOpeningStockKg: line.currentOpeningStockKg,
            totalIssuedKg: line.totalIssuedKg,
            closingStockKg: line.closingStockKg,
            uom: line.uom,
            monthKey: parsed.monthKey,
            monthLabel: parsed.monthLabel,
            sourceSnapshotId: parsed.monthKey,
            lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
      await batch.commit();
    }

    return {
      snapshotId: parsed.monthKey,
      monthKey: parsed.monthKey,
      monthLabel: parsed.monthLabel,
      importedLines: parsed.lines.length,
      message: "Fabrication raw material stock sheet imported successfully.",
    };
  },
);

/* =========================================================
   ================= WORKSPACE OTP ==========================
   ========================================================= */

export const sendWorkspaceOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const email =
      (request.data?.email ?? "").toString().trim().toLowerCase();
    const displayName = (request.data?.displayName ?? "").toString().trim();
    const logoUrl = (request.data?.logoUrl ?? "").toString();
    const companyData = request.data?.companyData ?? {};
    const adminPermissions = request.data?.adminPermissions ?? {};
    const selectedModuleIds = Array.isArray(request.data?.selectedModuleIds) ?
      request.data.selectedModuleIds
        .map((moduleId: unknown) => moduleId?.toString().trim())
        .filter((moduleId: string) => moduleId.length > 0) :
      [];

    if (!email) {
      throw new HttpsError("invalid-argument", "Email required");
    }

    if (!displayName) {
      throw new HttpsError("invalid-argument", "Display name required");
    }

    try {
      const existingUser = await admin.auth().getUserByEmail(email);
      const userSnap = await db.collection("users").doc(existingUser.uid).get();
      const userData = userSnap.data() || {};
      const companyId = (userData.companyId ?? "").toString().trim();
      const companyIds = Array.isArray(userData.companyIds) ?
        userData.companyIds :
        [];
      const memberships = userData.memberships ?? {};
      const membershipIds = typeof memberships === "object" ?
        Object.keys(memberships) :
        [];

      if (companyId || companyIds.length > 0 || membershipIds.length > 0) {
        throw new HttpsError(
          "already-exists",
          "This email is already registered",
        );
      }
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const code = (error as {code?: string}).code;
      if (code !== "auth/user-not-found") {
        throw error;
      }
    }

    const otp = generateOtp();
    const draftRef = db.collection("workspace_requests").doc();
    const companyId = db.collection("companies").doc().id;

    await draftRef.set({
      draftId: draftRef.id,
      registrationId: draftRef.id,
      companyId,
      email,
      displayName,
      logoUrl,
      companyData,
      adminPermissions,
      selectedModuleIds,
      otp,
      verified: false,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Workspace Verification OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {draftId: draftRef.id, registrationId: draftRef.id};
  },
);

export const resendWorkspaceOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const draftId =
      (request.data?.registrationId ?? request.data?.draftId ?? "")
        .toString()
        .trim();

    if (!draftId) {
      throw new HttpsError("invalid-argument", "Draft ID required");
    }

    const ref = db.collection("workspace_requests").doc(draftId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};
    const status = (data.status ?? "").toString();

    if (status === "completed") {
      throw new HttpsError(
        "failed-precondition",
        "Workspace registration is already completed",
      );
    }

    const email = (data.email ?? "").toString().trim().toLowerCase();
    if (!email) {
      throw new HttpsError("failed-precondition", "Draft email missing");
    }

    const otp = generateOtp();

    await ref.update({
      otp,
      ...legacyRequestSecretDeletes(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Resend Workspace OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {success: true};
  },
);

export const verifyWorkspaceOtpAndCreateWorkspace = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const draftId =
      (request.data?.registrationId ?? request.data?.draftId ?? "")
        .toString()
        .trim();
    const otp = (request.data?.otp ?? "").toString().trim();

    if (!draftId || !otp) {
      throw new HttpsError("invalid-argument", "Missing data");
    }

    const ref = db.collection("workspace_requests").doc(draftId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};

    if (data.otp !== otp) {
      throw new HttpsError("invalid-argument", "Invalid OTP");
    }

    const companyId = (data.companyId ?? "").toString().trim() ||
      db.collection("companies").doc().id;

    await ref.update({
      companyId,
      verified: true,
      status: "verified",
      ...legacyRequestSecretDeletes(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      draftId,
      registrationId: draftId,
      email: data.email,
      displayName: data.displayName,
      logoUrl: data.logoUrl ?? "",
      companyId,
      companyData: data.companyData ?? {},
      adminPermissions: data.adminPermissions ?? {},
      selectedModuleIds: data.selectedModuleIds ?? [],
    };
  },
);

/* =========================================================
   ================= JOIN COMPANY OTP =======================
   ========================================================= */

export const sendJoinCompanyOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const inviteCode =
      (request.data?.inviteCode ?? "").toString().trim().toUpperCase();
    const fullName = (request.data?.fullName ?? "").toString().trim();
    const email =
      (request.data?.email ?? "").toString().trim().toLowerCase();

    if (!inviteCode) {
      throw new HttpsError("invalid-argument", "Invite code required");
    }

    if (!fullName) {
      throw new HttpsError("invalid-argument", "Full name required");
    }

    if (!email) {
      throw new HttpsError("invalid-argument", "Email required");
    }

    try {
      const existingUser = await admin.auth().getUserByEmail(email);
      const userSnap = await db.collection("users").doc(existingUser.uid).get();
      const userData = userSnap.data() || {};
      const companyId = (userData.companyId ?? "").toString().trim();
      const companyIds = Array.isArray(userData.companyIds) ?
        userData.companyIds :
        [];
      const memberships = userData.memberships ?? {};
      const membershipIds = typeof memberships === "object" ?
        Object.keys(memberships) :
        [];

      if (companyId || companyIds.length > 0 || membershipIds.length > 0) {
        throw new HttpsError(
          "already-exists",
          "This email is already registered",
        );
      }
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const code = (error as {code?: string}).code;
      if (code !== "auth/user-not-found") {
        throw error;
      }
    }

    const inviteQuery = await db
      .collectionGroup("invites")
      .where("code", "==", inviteCode)
      .where("status", "==", "pending")
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (inviteQuery.empty) {
      throw new HttpsError(
        "not-found",
        "Invalid or already used invite code",
      );
    }

    const inviteDoc = inviteQuery.docs[0];
    const inviteData = inviteDoc.data();
    const companyRef = inviteDoc.ref.parent.parent;

    if (!companyRef) {
      throw new HttpsError("failed-precondition", "Company not found");
    }

    const companySnap = await companyRef.get();
    const companyData = companySnap.data() || {};

    const companyName =
      (companyData.companyName ?? companyData.name ?? "")
        .toString()
        .trim();

    const inviteEmail =
      (inviteData.email ?? "").toString().trim().toLowerCase();

    if (inviteEmail && inviteEmail !== email) {
      throw new HttpsError(
        "permission-denied",
        "Invite is for another email",
      );
    }

    const otp = generateOtp();
    const draftRef = db.collection("join_company_requests").doc();

    await draftRef.set({
      draftId: draftRef.id,
      inviteCode,
      inviteId: inviteDoc.id,
      companyId: companyRef.id,
      companyName,
      fullName,
      email,
      role: inviteData.role ?? "sales",
      isAdmin: inviteData.role === "admin",
      phone: inviteData.phone ?? "",
      permissions: inviteData.permissions ?? {},
      verified: false,
      status: "pending",
      otp,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Join Company OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {draftId: draftRef.id};
  },
);

export const resendJoinCompanyOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const draftId = request.data?.draftId;

    if (!draftId) {
      throw new HttpsError("invalid-argument", "Draft ID required");
    }

    const ref = db.collection("join_company_requests").doc(draftId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};
    const email = data.email;

    const otp = generateOtp();

    await ref.update({
      otp,
      ...legacyRequestSecretDeletes(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Resend OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {success: true};
  },
);

export const verifyJoinCompanyOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const draftId = request.data?.draftId;
    const otp = request.data?.otp;

    if (!draftId || !otp) {
      throw new HttpsError("invalid-argument", "Missing data");
    }

    const ref = db.collection("join_company_requests").doc(draftId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};

    if (data.otp !== otp) {
      throw new HttpsError("invalid-argument", "Invalid OTP");
    }

    await ref.update({
      verified: true,
      status: "verified",
      ...legacyRequestSecretDeletes(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      email: data.email,
      fullName: data.fullName,
      companyId: data.companyId,
      companyName: data.companyName,
      inviteId: data.inviteId,
      role: data.role,
      isAdmin: data.isAdmin,
      phone: data.phone,
      permissions: data.permissions,
    };
  },
);


/* ===================== PASSWORD OTP RESET ===================== */

const passwordResetCollection = "passwordResetOtps";
const otpExpiryMs = 10 * 60 * 1000;
const resetTokenExpiryMs = 10 * 60 * 1000;

/**
 * Hashes a sensitive reset value.
 * @param {string} value raw value
 * @return {string}
 */
function hashResetSecret(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

/**
 * Builds Firestore doc id from email.
 * @param {string} email normalized email
 * @return {string}
 */
function passwordResetDocId(email: string): string {
  return hashResetSecret(email);
}

/**
 * Compares two hex strings safely.
 * @param {string} left first value
 * @param {string} right second value
 * @return {boolean}
 */
function safeHexCompare(left: string, right: string): boolean {
  if (!left || !right || left.length !== right.length) return false;
  return timingSafeEqual(Buffer.from(left, "hex"), Buffer.from(right, "hex"));
}

/**
 * Reads Firestore timestamp safely.
 * @param {unknown} value timestamp-like value
 * @return {number}
 */
function timestampMillis(value: unknown): number {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  return 0;
}

/**
 * Sends password reset OTP email.
 * @param {string} email recipient email
 * @param {string} otp one time password
 * @return {Promise<void>}
 */
async function sendPasswordOtpEmail(
  email: string,
  otp: string,
): Promise<void> {
  const transporter = buildTransporter();

  await transporter.sendMail({
    from: `"QUIK ERP" <${gmailUser.value()}>`,
    to: email,
    subject: "QUIK ERP Password Reset OTP",
    text:
      `Your QUIK ERP password reset OTP is ${otp}.\n\n` +
      "This OTP is valid for 10 minutes. Do not share it with anyone.",
    html:
      "<p>Your QUIK ERP password reset OTP is:</p>" +
      `<h2 style="letter-spacing:4px">${otp}</h2>` +
      "<p>This OTP is valid for 10 minutes.</p>" +
      "<p>Do not share it with anyone.</p>",
  });
}

export const requestPasswordOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const email = callableString(request.data?.email).toLowerCase();

    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "Enter a valid email.");
    }

    try {
      const user = await admin.auth().getUserByEmail(email);
      const otp = generateOtp();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        Date.now() + otpExpiryMs,
      );

      await db.collection(passwordResetCollection)
        .doc(passwordResetDocId(email))
        .set({
          email,
          uid: user.uid,
          otpHash: hashResetSecret(`otp:${email}:${otp}`),
          attempts: 0,
          used: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt,
        });

      await sendPasswordOtpEmail(email, otp);
    } catch (error) {
      const code = (error as {code?: string}).code;
      if (code === "auth/user-not-found") {
        return {ok: true};
      }

      console.error("requestPasswordOtp failed", error);
      throw new HttpsError(
        "internal",
        "OTP could not be sent. Please try again later.",
      );
    }

    return {ok: true};
  },
);

export const verifyPasswordOtp = onCall(async (request) => {
  const email = callableString(request.data?.email).toLowerCase();
  const otp = callableString(request.data?.otp);

  if (!email || !otp) {
    throw new HttpsError("invalid-argument", "Email and OTP are required.");
  }

  const ref = db.collection(passwordResetCollection)
    .doc(passwordResetDocId(email));
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("failed-precondition", "Invalid or expired OTP.");
  }

  const data = snap.data() || {};
  const expiresAtMs = timestampMillis(data.expiresAt);
  const attempts = typeof data.attempts === "number" ? data.attempts : 0;

  if (
    data.used === true ||
    attempts >= 5 ||
    expiresAtMs <= Date.now()
  ) {
    throw new HttpsError("failed-precondition", "Invalid or expired OTP.");
  }

  const expectedHash = callableString(data.otpHash);
  const enteredHash = hashResetSecret(`otp:${email}:${otp}`);

  if (!safeHexCompare(expectedHash, enteredHash)) {
    await ref.set({
      attempts: admin.firestore.FieldValue.increment(1),
      lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    throw new HttpsError("failed-precondition", "Invalid or expired OTP.");
  }

  const resetToken = randomBytes(32).toString("hex");
  const tokenExpiresAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + resetTokenExpiryMs,
  );

  await ref.set({
    resetTokenHash: hashResetSecret(`token:${email}:${resetToken}`),
    tokenExpiresAt,
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {ok: true, resetToken};
});

export const resetPasswordWithOtp = onCall(async (request) => {
  const email = callableString(request.data?.email).toLowerCase();
  const resetToken = callableString(request.data?.resetToken);
  const newPassword = callableString(request.data?.newPassword);

  if (!email || !resetToken || newPassword.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Email, valid OTP session and password are required.",
    );
  }

  const ref = db.collection(passwordResetCollection)
    .doc(passwordResetDocId(email));
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Password reset session expired.",
    );
  }

  const data = snap.data() || {};
  const tokenExpiresAtMs = timestampMillis(data.tokenExpiresAt);
  const expectedTokenHash = callableString(data.resetTokenHash);
  const enteredTokenHash = hashResetSecret(`token:${email}:${resetToken}`);
  const uid = callableString(data.uid);

  if (
    !uid ||
    data.used === true ||
    tokenExpiresAtMs <= Date.now() ||
    !safeHexCompare(expectedTokenHash, enteredTokenHash)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Password reset session expired.",
    );
  }

  await admin.auth().updateUser(uid, {password: newPassword});
  await ref.delete();

  return {ok: true};
});
