#!/usr/bin/env node

/**
 * Cursor Chat History Cleaner
 * 
 * This script processes exported chat history from export_chats.py,
 * cleaning markdown formatting, filtering by project keywords, and
 * organizing conversations for easier review.
 * 
 * Usage:
 *   node clean_history.js --input exports/cursor_chats_*.json --project "job-assistant-app" --output cleaned/
 */

const fs = require('fs');
const path = require('path');
const { program } = require('commander');

class ChatHistoryCleaner {
    constructor(options = {}) {
        this.options = {
            minMessageLength: 20,
            maxMessageLength: 10000,
            removeTimestamps: true,
            cleanMarkdown: true,
            filterByProject: true,
            groupByConversation: true,
            ...options
        };
        
        // Common project keywords to look for
        this.projectKeywords = [
            'rails', 'ruby', 'api', 'authentication', 'database',
            'model', 'controller', 'service', 'migration', 'gem',
            'endpoint', 'jwt', 'oauth', 'session', 'user', 'login'
        ];
        
        // Patterns to identify different types of content
        this.patterns = {
            codeBlock: /```[\s\S]*?```/g,
            inlineCode: /`[^`]+`/g,
            markdown: /[*_#>\-\[\]]/g,
            timestamp: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/g,
            url: /https?:\/\/[^\s]+/g,
            filePath: /[\/\\][\w\-\.\/\\]+\.(rb|js|py|json|yml|yaml|md)/g,
            errorMessage: /(error|exception|failed|undefined|null)/i
        };
    }

    /**
     * Load and parse the exported chat data
     */
    loadChatData(inputFile) {
        console.log(`📖 Loading chat data from: ${inputFile}`);
        
        if (!fs.existsSync(inputFile)) {
            throw new Error(`Input file not found: ${inputFile}`);
        }
        
        const rawData = fs.readFileSync(inputFile, 'utf8');
        const data = JSON.parse(rawData);
        
        console.log(`✅ Loaded ${data.chats?.length || 0} chat entries`);
        console.log(`📊 Export info:`, data.export_info);
        
        return data;
    }

    /**
     * Filter chats by project relevance
     */
    filterByProject(chats, projectName = null) {
        console.log(`🔍 Filtering by project relevance...`);
        
        const filtered = chats.filter(chat => {
            const content = (chat.text_content || '').toLowerCase();
            
            // Check for project name if provided
            if (projectName && content.includes(projectName.toLowerCase())) {
                return true;
            }
            
            // Check for general project keywords
            const hasProjectKeywords = this.projectKeywords.some(keyword => 
                content.includes(keyword)
            );
            
            // Check for code patterns
            const hasCode = this.patterns.codeBlock.test(content) || 
                           this.patterns.inlineCode.test(content) ||
                           this.patterns.filePath.test(content);
            
            // Check for development discussions
            const hasDevelopmentContent = [
                'implement', 'function', 'class', 'method', 'variable',
                'debug', 'fix', 'error', 'issue', 'feature', 'add',
                'create', 'update', 'delete', 'modify', 'change'
            ].some(term => content.includes(term));
            
            return hasProjectKeywords || hasCode || hasDevelopmentContent;
        });
        
        console.log(`✅ Filtered to ${filtered.length} project-relevant entries`);
        return filtered;
    }

    /**
     * Clean markdown and formatting from text
     */
    cleanText(text) {
        if (!text || typeof text !== 'string') return '';
        
        let cleaned = text;
        
        if (this.options.cleanMarkdown) {
            // Preserve code blocks but clean their formatting
            const codeBlocks = [];
            cleaned = cleaned.replace(this.patterns.codeBlock, (match, index) => {
                codeBlocks.push(match);
                return `__CODE_BLOCK_${codeBlocks.length - 1}__`;
            });
            
            // Clean markdown formatting
            cleaned = cleaned
                .replace(/\*\*(.*?)\*\*/g, '$1')  // Bold
                .replace(/\*(.*?)\*/g, '$1')      // Italic
                .replace(/__(.*?)__/g, '$1')     // Bold underscore
                .replace(/_(.*?)_/g, '$1')       // Italic underscore
                .replace(/#{1,6}\s*/g, '')       // Headers
                .replace(/>\s*/g, '')            // Blockquotes
                .replace(/^\s*[-*+]\s+/gm, '')   // List items
                .replace(/^\s*\d+\.\s+/gm, '')   // Numbered lists
                .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1'); // Links
            
            // Restore code blocks
            codeBlocks.forEach((block, index) => {
                cleaned = cleaned.replace(`__CODE_BLOCK_${index}__`, block);
            });
        }
        
        if (this.options.removeTimestamps) {
            cleaned = cleaned.replace(this.patterns.timestamp, '[TIMESTAMP]');
        }
        
        // Clean up whitespace
        cleaned = cleaned
            .replace(/\n\s*\n\s*\n/g, '\n\n')  // Multiple line breaks
            .replace(/[ \t]+/g, ' ')           // Multiple spaces
            .trim();
        
        return cleaned;
    }

    /**
     * Extract code snippets from text
     */
    extractCodeSnippets(text) {
        const snippets = [];
        
        // Extract code blocks
        const codeBlocks = text.match(this.patterns.codeBlock) || [];
        codeBlocks.forEach(block => {
            const lines = block.split('\n');
            const language = lines[0].replace('```', '').trim();
            const code = lines.slice(1, -1).join('\n');
            
            if (code.trim()) {
                snippets.push({
                    type: 'block',
                    language: language || 'unknown',
                    code: code.trim()
                });
            }
        });
        
        // Extract inline code
        const inlineCode = text.match(this.patterns.inlineCode) || [];
        inlineCode.forEach(code => {
            const cleaned = code.replace(/`/g, '').trim();
            if (cleaned.length > 5) {  // Skip very short inline code
                snippets.push({
                    type: 'inline',
                    code: cleaned
                });
            }
        });
        
        return snippets;
    }

    /**
     * Analyze content for key information
     */
    analyzeContent(chat) {
        const content = chat.text_content || '';
        
        const analysis = {
            hasCode: this.patterns.codeBlock.test(content) || this.patterns.inlineCode.test(content),
            hasError: this.patterns.errorMessage.test(content),
            hasFilePath: this.patterns.filePath.test(content),
            hasUrl: this.patterns.url.test(content),
            wordCount: content.split(/\s+/).length,
            codeSnippets: this.extractCodeSnippets(content),
            matchedKeywords: chat.matched_keywords || [],
            importance: 0
        };
        
        // Calculate importance score
        analysis.importance += analysis.hasCode ? 3 : 0;
        analysis.importance += analysis.hasError ? 2 : 0;
        analysis.importance += analysis.hasFilePath ? 2 : 0;
        analysis.importance += analysis.matchedKeywords.length;
        analysis.importance += Math.min(analysis.wordCount / 100, 3);
        
        return analysis;
    }

    /**
     * Group chats by conversation/workspace
     */
    groupByConversation(chats) {
        console.log(`📋 Grouping chats by workspace...`);
        
        const groups = {};
        
        chats.forEach(chat => {
            const workspaceId = chat.workspace?.workspace_id || 'unknown';
            
            if (!groups[workspaceId]) {
                groups[workspaceId] = {
                    workspace_info: chat.workspace,
                    chats: [],
                    total_importance: 0,
                    has_code: false,
                    keywords: new Set()
                };
            }
            
            const analysis = this.analyzeContent(chat);
            chat.analysis = analysis;
            
            groups[workspaceId].chats.push(chat);
            groups[workspaceId].total_importance += analysis.importance;
            groups[workspaceId].has_code = groups[workspaceId].has_code || analysis.hasCode;
            
            analysis.matchedKeywords.forEach(keyword => 
                groups[workspaceId].keywords.add(keyword)
            );
        });
        
        // Convert keywords set to array
        Object.values(groups).forEach(group => {
            group.keywords = Array.from(group.keywords);
        });
        
        console.log(`✅ Grouped into ${Object.keys(groups).length} workspaces`);
        return groups;
    }

    /**
     * Generate a summary of the chat data
     */
    generateSummary(groups) {
        const summary = {
            total_workspaces: Object.keys(groups).length,
            total_chats: 0,
            workspaces_with_code: 0,
            top_keywords: {},
            most_important_workspaces: []
        };
        
        Object.entries(groups).forEach(([workspaceId, group]) => {
            summary.total_chats += group.chats.length;
            
            if (group.has_code) {
                summary.workspaces_with_code++;
            }
            
            // Count keywords
            group.keywords.forEach(keyword => {
                summary.top_keywords[keyword] = (summary.top_keywords[keyword] || 0) + 1;
            });
            
            // Track important workspaces
            summary.most_important_workspaces.push({
                workspace_id: workspaceId,
                importance: group.total_importance,
                chat_count: group.chats.length,
                has_code: group.has_code,
                keywords: group.keywords
            });
        });
        
        // Sort workspaces by importance
        summary.most_important_workspaces.sort((a, b) => b.importance - a.importance);
        summary.most_important_workspaces = summary.most_important_workspaces.slice(0, 10);
        
        // Sort keywords by frequency
        summary.top_keywords = Object.entries(summary.top_keywords)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 20)
            .reduce((obj, [key, value]) => {
                obj[key] = value;
                return obj;
            }, {});
        
        return summary;
    }

    /**
     * Process and clean the chat history
     */
    process(inputFile, options = {}) {
        const opts = { ...this.options, ...options };
        
        console.log(`🚀 Starting chat history cleaning...`);
        console.log(`⚙️  Options:`, opts);
        
        // Load data
        const data = this.loadChatData(inputFile);
        let chats = data.chats || [];
        
        if (chats.length === 0) {
            console.log(`⚠️  No chats found in input file`);
            return null;
        }
        
        // Filter by project relevance
        if (opts.filterByProject) {
            chats = this.filterByProject(chats, opts.projectName);
        }
        
        // Filter by message length
        chats = chats.filter(chat => {
            const content = chat.text_content || '';
            return content.length >= opts.minMessageLength && 
                   content.length <= opts.maxMessageLength;
        });
        
        console.log(`✅ After length filtering: ${chats.length} chats`);
        
        // Clean text content
        chats.forEach(chat => {
            if (chat.text_content) {
                chat.cleaned_content = this.cleanText(chat.text_content);
            }
        });
        
        // Group by conversation
        const groups = this.groupByConversation(chats);
        
        // Generate summary
        const summary = this.generateSummary(groups);
        
        return {
            summary,
            groups,
            original_export_info: data.export_info,
            processing_options: opts,
            processed_at: new Date().toISOString()
        };
    }

    /**
     * Save processed data to files
     */
    save(processedData, outputDir, baseFilename = 'cleaned_chats') {
        console.log(`💾 Saving processed data to: ${outputDir}`);
        
        // Create output directory
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }
        
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
        
        // Save complete processed data
        const mainFile = path.join(outputDir, `${baseFilename}_${timestamp}.json`);
        fs.writeFileSync(mainFile, JSON.stringify(processedData, null, 2));
        console.log(`✅ Main file: ${mainFile}`);
        
        // Save summary
        const summaryFile = path.join(outputDir, `summary_${timestamp}.json`);
        fs.writeFileSync(summaryFile, JSON.stringify(processedData.summary, null, 2));
        console.log(`✅ Summary: ${summaryFile}`);
        
        // Save individual workspace files for important ones
        const workspaceDir = path.join(outputDir, 'workspaces');
        if (!fs.existsSync(workspaceDir)) {
            fs.mkdirSync(workspaceDir);
        }
        
        processedData.summary.most_important_workspaces.slice(0, 5).forEach(workspace => {
            const workspaceData = processedData.groups[workspace.workspace_id];
            const filename = `workspace_${workspace.workspace_id}_${timestamp}.json`;
            const filepath = path.join(workspaceDir, filename);
            
            fs.writeFileSync(filepath, JSON.stringify(workspaceData, null, 2));
            console.log(`✅ Workspace: ${filepath}`);
        });
        
        // Generate readable text reports
        this.generateTextReports(processedData, outputDir, timestamp);
        
        return {
            mainFile,
            summaryFile,
            outputDir
        };
    }

    /**
     * Generate human-readable text reports
     */
    generateTextReports(processedData, outputDir, timestamp) {
        // Summary report
        const summaryText = this.formatSummaryReport(processedData);
        const summaryTextFile = path.join(outputDir, `summary_${timestamp}.txt`);
        fs.writeFileSync(summaryTextFile, summaryText);
        console.log(`✅ Text summary: ${summaryTextFile}`);
        
        // Code snippets report
        const codeReport = this.formatCodeReport(processedData);
        const codeReportFile = path.join(outputDir, `code_snippets_${timestamp}.txt`);
        fs.writeFileSync(codeReportFile, codeReport);
        console.log(`✅ Code report: ${codeReportFile}`);
    }

    /**
     * Format summary as readable text
     */
    formatSummaryReport(data) {
        const { summary, original_export_info } = data;
        
        let report = `# Cursor Chat History Analysis Report\n\n`;
        report += `Generated: ${new Date().toLocaleString()}\n`;
        report += `Original export: ${original_export_info?.timestamp || 'unknown'}\n\n`;
        
        report += `## Overview\n`;
        report += `- Total workspaces: ${summary.total_workspaces}\n`;
        report += `- Total chats: ${summary.total_chats}\n`;
        report += `- Workspaces with code: ${summary.workspaces_with_code}\n\n`;
        
        report += `## Top Keywords\n`;
        Object.entries(summary.top_keywords).forEach(([keyword, count]) => {
            report += `- ${keyword}: ${count} occurrences\n`;
        });
        
        report += `\n## Most Important Workspaces\n`;
        summary.most_important_workspaces.forEach((workspace, index) => {
            report += `\n### ${index + 1}. Workspace: ${workspace.workspace_id}\n`;
            report += `- Importance score: ${workspace.importance}\n`;
            report += `- Chat count: ${workspace.chat_count}\n`;
            report += `- Has code: ${workspace.has_code ? 'Yes' : 'No'}\n`;
            report += `- Keywords: ${workspace.keywords.join(', ')}\n`;
        });
        
        return report;
    }

    /**
     * Format code snippets report
     */
    formatCodeReport(data) {
        let report = `# Code Snippets from Chat History\n\n`;
        
        Object.entries(data.groups).forEach(([workspaceId, group]) => {
            const codeSnippets = [];
            
            group.chats.forEach(chat => {
                if (chat.analysis?.codeSnippets?.length > 0) {
                    codeSnippets.push(...chat.analysis.codeSnippets);
                }
            });
            
            if (codeSnippets.length > 0) {
                report += `## Workspace: ${workspaceId}\n\n`;
                
                codeSnippets.forEach((snippet, index) => {
                    report += `### Snippet ${index + 1} (${snippet.type})\n`;
                    if (snippet.language) {
                        report += `Language: ${snippet.language}\n`;
                    }
                    report += `\`\`\`${snippet.language || ''}\n${snippet.code}\n\`\`\`\n\n`;
                });
            }
        });
        
        return report;
    }
}

// CLI setup
program
    .name('clean_history')
    .description('Clean and process Cursor chat history exports')
    .version('1.0.0');

program
    .requiredOption('-i, --input <file>', 'Input JSON file from export_chats.py')
    .option('-o, --output <dir>', 'Output directory', './cleaned')
    .option('-p, --project <name>', 'Project name to filter by')
    .option('--min-length <number>', 'Minimum message length', '20')
    .option('--max-length <number>', 'Maximum message length', '10000')
    .option('--no-clean-markdown', 'Keep markdown formatting')
    .option('--no-filter-project', 'Skip project relevance filtering')
    .action((options) => {
        try {
            const cleaner = new ChatHistoryCleaner();
            
            const processedData = cleaner.process(options.input, {
                projectName: options.project,
                minMessageLength: parseInt(options.minLength),
                maxMessageLength: parseInt(options.maxLength),
                cleanMarkdown: options.cleanMarkdown,
                filterByProject: options.filterProject
            });
            
            if (!processedData) {
                console.log('❌ No data to process');
                process.exit(1);
            }
            
            const result = cleaner.save(processedData, options.output);
            
            console.log('\n🎉 Processing complete!');
            console.log(`📊 Summary: ${processedData.summary.total_chats} chats processed`);
            console.log(`📁 Output directory: ${result.outputDir}`);
            console.log('\n💡 Next steps:');
            console.log('1. Review the summary report');
            console.log('2. Check individual workspace files for relevant conversations');
            console.log('3. Look at code snippets report for implementation details');
            
        } catch (error) {
            console.error('❌ Error:', error.message);
            process.exit(1);
        }
    });

// Handle missing commander dependency
if (require.main === module) {
    try {
        program.parse();
    } catch (error) {
        if (error.code === 'MODULE_NOT_FOUND' && error.message.includes('commander')) {
            console.log('📦 Installing required dependency: commander');
            console.log('Run: npm install commander');
            console.log('\nOr use directly:');
            console.log('const cleaner = new ChatHistoryCleaner();');
            console.log('const result = cleaner.process("input.json", options);');
            process.exit(1);
        }
        throw error;
    }
}

module.exports = ChatHistoryCleaner;
