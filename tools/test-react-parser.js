#!/usr/bin/env node
/**
 * Test React E2 parser against production doctext samples
 *
 * This script analyzes 100K real writeup samples to identify:
 * - Parsing edge cases
 * - Complex bracket nesting
 * - Malformed links
 * - HTML + E2 formatting interactions
 */

const fs = require('fs');
const path = require('path');

// Simple server-side implementation of ParseLinks logic
// (Mimics the React component's parsing behavior)
function parseE2Links(text) {
  const results = {
    text,
    externalLinks: [],
    internalLinks: [],
    errors: [],
    warnings: []
  };

  if (!text) return results;

  const textString = String(text);

  // Pattern for external links: [http://url] or [http://url|text] or [http://url|]
  const externalLinkPattern = /\[\s*(https?:\/\/[^\]|[\]<>"]+)(?:\|\s*([^\]|[\]]*)?)?\]/g;

  // Pattern for internal links
  const internalLinkPattern = /\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)\]/g;

  // First pass: Find all external links
  let match;
  while ((match = externalLinkPattern.exec(textString)) !== null) {
    const url = match[1];
    let display = match[2];

    if (match[0].includes('|') && (!display || display.trim() === '')) {
      display = '[link]';
    } else if (!display) {
      display = url;
    }

    results.externalLinks.push({
      start: match.index,
      end: match.index + match[0].length,
      url,
      display,
      raw: match[0]
    });
  }

  // Second pass: Find all internal links (avoiding external link positions)
  internalLinkPattern.lastIndex = 0;
  while ((match = internalLinkPattern.exec(textString)) !== null) {
    const start = match.index;
    const end = match.index + match[0].length;

    // Check if this overlaps with an external link
    const overlaps = results.externalLinks.some(ext =>
      (start >= ext.start && start < ext.end) ||
      (end > ext.start && end <= ext.end)
    );

    if (!overlaps) {
      const content = match[1];
      const link = {
        start,
        end,
        raw: match[0],
        content
      };

      // Parse nested bracket syntax: [title[nodetype]] or [display|title[nodetype]]
      const pipeAndBracketMatch = content.match(/^([^|[\]]+)\|([^[\]]+)\[([^\]|]+)\]$/);
      if (pipeAndBracketMatch) {
        link.display = pipeAndBracketMatch[1].trim();
        link.title = pipeAndBracketMatch[2].trim();
        const typeSpec = pipeAndBracketMatch[3].trim();

        if (typeSpec.includes(' by ')) {
          const [type, auth] = typeSpec.split(/\s+by\s+/);
          link.nodetype = type.trim();
          link.author = auth.trim();
        } else if (/^\d+$/.test(typeSpec)) {
          link.anchor = `debatecomment_${typeSpec}`;
          link.title = link.title;
        } else {
          link.nodetype = typeSpec;
        }
      } else {
        const nestedMatch = content.match(/^([^[\]|]+)\[([^\]|]+)\]$/);
        if (nestedMatch) {
          link.title = nestedMatch[1].trim();
          link.display = link.title;
          const typeSpec = nestedMatch[2].trim();

          if (typeSpec.includes(' by ')) {
            const [type, auth] = typeSpec.split(/\s+by\s+/);
            link.nodetype = type.trim() || 'writeup';
            link.author = auth.trim();
          } else if (/^\d+$/.test(typeSpec)) {
            link.anchor = `debatecomment_${typeSpec}`;
          } else {
            link.nodetype = typeSpec;
          }
        } else if (content.includes('|')) {
          const pipeParts = content.split('|');
          link.title = pipeParts[0].trim();
          link.display = pipeParts[1].trim();
        } else {
          link.title = content.trim();
          link.display = link.title;
        }
      }

      results.internalLinks.push(link);
    }
  }

  return results;
}

// Analyze patterns and edge cases
function analyzeDoctext(samples) {
  console.log('Analyzing 100,000 doctext samples...\n');

  const stats = {
    totalSamples: samples.length,
    totalLinks: 0,
    externalLinks: 0,
    internalLinks: 0,
    complexPatterns: {
      nestedBrackets: 0,
      pipeSyntax: 0,
      htmlTags: 0,
      mixedHtmlE2: 0,
      deepNesting: 0,
      unclosedBrackets: 0,
      emptyBrackets: 0,
      multipleConsecutive: 0
    },
    edgeCases: []
  };

  const edgeCaseExamples = {
    deeplyNested: [],
    complexMixed: [],
    malformed: [],
    unusual: []
  };

  samples.forEach((sample, index) => {
    const result = parseE2Links(sample.text);
    const linkCount = result.externalLinks.length + result.internalLinks.length;

    stats.totalLinks += linkCount;
    stats.externalLinks += result.externalLinks.length;
    stats.internalLinks += result.internalLinks.length;

    // Count complex patterns
    if (sample.text.includes('[') && sample.text.includes(']')) {
      const bracketDepth = (sample.text.match(/\[/g) || []).length;
      const closingDepth = (sample.text.match(/\]/g) || []).length;

      if (bracketDepth !== closingDepth) {
        stats.complexPatterns.unclosedBrackets++;
        if (edgeCaseExamples.malformed.length < 10) {
          edgeCaseExamples.malformed.push({
            id: sample.id,
            text: sample.text.substring(0, 200),
            reason: `Mismatched brackets: ${bracketDepth} open, ${closingDepth} close`
          });
        }
      }

      if (bracketDepth > 10) {
        stats.complexPatterns.deepNesting++;
        if (edgeCaseExamples.deeplyNested.length < 10) {
          edgeCaseExamples.deeplyNested.push({
            id: sample.id,
            text: sample.text.substring(0, 200),
            bracketCount: bracketDepth
          });
        }
      }
    }

    if (sample.text.match(/\[\]/)) {
      stats.complexPatterns.emptyBrackets++;
    }

    if (sample.text.match(/\]\s*\[/)) {
      stats.complexPatterns.multipleConsecutive++;
    }

    if (sample.text.includes('|')) {
      stats.complexPatterns.pipeSyntax++;
    }

    if (sample.text.match(/<[^>]+>/)) {
      stats.complexPatterns.htmlTags++;
      if (sample.text.includes('[') && sample.text.includes(']')) {
        stats.complexPatterns.mixedHtmlE2++;
        if (edgeCaseExamples.complexMixed.length < 10) {
          edgeCaseExamples.complexMixed.push({
            id: sample.id,
            text: sample.text.substring(0, 300)
          });
        }
      }
    }

    // Find unusual nested bracket patterns
    if (sample.text.match(/\[[^\]]*\[[^\]]*\[[^\]]*\]\]/)) {
      stats.complexPatterns.nestedBrackets++;
      if (edgeCaseExamples.unusual.length < 10) {
        edgeCaseExamples.unusual.push({
          id: sample.id,
          text: sample.text.substring(0, 200),
          reason: 'Triple nested brackets'
        });
      }
    }

    // Progress indicator
    if ((index + 1) % 10000 === 0) {
      process.stdout.write(`  Processed ${index + 1} samples...\r`);
    }
  });

  console.log(`  Processed ${samples.length} samples... ✓\n`);

  return { stats, edgeCaseExamples };
}

// Print results
function printResults(stats, edgeCaseExamples, metadata) {
  console.log('=' .repeat(80));
  console.log('E2 DOCTEXT PARSER ANALYSIS RESULTS');
  console.log('=' .repeat(80));
  console.log();

  console.log('Sample Statistics:');
  console.log(`  Total samples: ${stats.totalSamples.toLocaleString()}`);
  console.log(`  Length range: ${metadata.length_stats.min} - ${metadata.length_stats.max} chars`);
  console.log(`  Average length: ${metadata.length_stats.avg} chars`);
  console.log();

  console.log('Link Analysis:');
  console.log(`  Total links found: ${stats.totalLinks.toLocaleString()}`);
  console.log(`  External links: ${stats.externalLinks.toLocaleString()} (${(100 * stats.externalLinks / stats.totalLinks).toFixed(1)}%)`);
  console.log(`  Internal E2 links: ${stats.internalLinks.toLocaleString()} (${(100 * stats.internalLinks / stats.totalLinks).toFixed(1)}%)`);
  console.log(`  Links per sample (avg): ${(stats.totalLinks / stats.totalSamples).toFixed(2)}`);
  console.log();

  console.log('Complex Pattern Detection:');
  console.log(`  Pipe syntax [title|display]: ${stats.complexPatterns.pipeSyntax.toLocaleString()}`);
  console.log(`  HTML tags present: ${stats.complexPatterns.htmlTags.toLocaleString()}`);
  console.log(`  Mixed HTML + E2 links: ${stats.complexPatterns.mixedHtmlE2.toLocaleString()}`);
  console.log(`  Deep nesting (>10 brackets): ${stats.complexPatterns.deepNesting.toLocaleString()}`);
  console.log(`  Triple+ nested brackets: ${stats.complexPatterns.nestedBrackets.toLocaleString()}`);
  console.log(`  Unclosed brackets: ${stats.complexPatterns.unclosedBrackets.toLocaleString()}`);
  console.log(`  Empty brackets []: ${stats.complexPatterns.emptyBrackets.toLocaleString()}`);
  console.log(`  Consecutive links ][][: ${stats.complexPatterns.multipleConsecutive.toLocaleString()}`);
  console.log();

  console.log('Edge Case Examples:');
  console.log('=' .repeat(80));

  if (edgeCaseExamples.deeplyNested.length > 0) {
    console.log('\n1. DEEPLY NESTED BRACKETS:');
    edgeCaseExamples.deeplyNested.slice(0, 3).forEach((ex, i) => {
      console.log(`\n  Example ${i + 1} (ID ${ex.id}, ${ex.bracketCount} brackets):`);
      console.log(`  ${ex.text}...`);
    });
  }

  if (edgeCaseExamples.complexMixed.length > 0) {
    console.log('\n2. MIXED HTML + E2 LINKS:');
    edgeCaseExamples.complexMixed.slice(0, 3).forEach((ex, i) => {
      console.log(`\n  Example ${i + 1} (ID ${ex.id}):`);
      console.log(`  ${ex.text}...`);
    });
  }

  if (edgeCaseExamples.malformed.length > 0) {
    console.log('\n3. MALFORMED BRACKETS:');
    edgeCaseExamples.malformed.slice(0, 3).forEach((ex, i) => {
      console.log(`\n  Example ${i + 1} (ID ${ex.id}):`);
      console.log(`  ${ex.reason}`);
      console.log(`  ${ex.text}...`);
    });
  }

  if (edgeCaseExamples.unusual.length > 0) {
    console.log('\n4. UNUSUAL PATTERNS:');
    edgeCaseExamples.unusual.slice(0, 3).forEach((ex, i) => {
      console.log(`\n  Example ${i + 1} (ID ${ex.id}):`);
      console.log(`  ${ex.reason}`);
      console.log(`  ${ex.text}...`);
    });
  }

  console.log();
  console.log('=' .repeat(80));
  console.log('CONCLUSION:');
  console.log('=' .repeat(80));

  const safetyScore = 100 - (
    (stats.complexPatterns.unclosedBrackets / stats.totalSamples * 100) +
    (stats.complexPatterns.deepNesting / stats.totalSamples * 10)
  );

  console.log();
  console.log(`Safety Score: ${safetyScore.toFixed(2)}%`);
  console.log();

  if (stats.complexPatterns.unclosedBrackets > stats.totalSamples * 0.001) {
    console.log('⚠️  WARNING: High rate of unclosed brackets detected');
    console.log(`   ${stats.complexPatterns.unclosedBrackets} samples (${(100 * stats.complexPatterns.unclosedBrackets / stats.totalSamples).toFixed(2)}%) have mismatched brackets`);
  } else {
    console.log('✓ Low rate of malformed brackets - React parser should handle well');
  }

  if (stats.complexPatterns.mixedHtmlE2 > 0) {
    console.log(`✓ ${stats.complexPatterns.mixedHtmlE2.toLocaleString()} samples mix HTML + E2 links - verify HTML sanitization`);
  }

  if (stats.complexPatterns.deepNesting > 0) {
    console.log(`✓ ${stats.complexPatterns.deepNesting.toLocaleString()} samples have deep nesting - may need regex optimization`);
  }

  console.log();
  console.log('Recommendation:');
  if (safetyScore > 99) {
    console.log('  ✅ SAFE to migrate to client-side React parsing');
    console.log('  The React parser should handle 99%+ of production writeups correctly.');
  } else if (safetyScore > 95) {
    console.log('  ⚠️  MOSTLY SAFE with minor edge cases');
    console.log('  Review the edge cases above and add additional test coverage.');
  } else {
    console.log('  ❌ NOT SAFE - significant parsing issues detected');
    console.log('  Fix edge cases before migrating to client-side parsing.');
  }

  console.log();
}

// Main execution
function main() {
  const dataFile = path.resolve(__dirname, '../../e2-doctext/doctext-samples.json');

  if (!fs.existsSync(dataFile)) {
    console.error(`Error: Data file not found: ${dataFile}`);
    console.error('Run ./tools/extract-doctext-for-parser-test.py first');
    process.exit(1);
  }

  console.log('Loading doctext samples...');
  const data = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
  console.log(`Loaded ${data.samples.length.toLocaleString()} samples\n`);

  const { stats, edgeCaseExamples } = analyzeDoctext(data.samples);
  printResults(stats, edgeCaseExamples, data.metadata);
}

main();
