import { LightningElement, track, api, wire } from 'lwc';
import botAvatar from '@salesforce/resourceUrl/botAvatar';
import startChatSession from '@salesforce/apex/EinsteinChatController.startChatSession';
import sendChatMessage from '@salesforce/apex/EinsteinChatController.sendChatMessage';
import getMetadataInfo from '@salesforce/apex/EinsteinChatController.getMetadataInfo';
import userAvatar from '@salesforce/resourceUrl/userAvatar';
import chatbotLogo from '@salesforce/resourceUrl/chatbotLogo';
//import getAnswer from '@salesforce/apex/ChatbotClass.chatbotMethod';
export default class agentChatbot extends LightningElement {
    @track isFullscreen = false;
    @api recordId;
    @track url = '';
    @track scrap_number = '';
    @track containerStyle = 'display: none; bottom: 100px; right: 26px;';
    @track chatMessagesStyle = 'height:62%';
    @track isOpen = false;
    @track messages = [];
    @track newMessage = '';
    @track isBotTyping = false;
    @track showQuickReplies = false;
    @track quickReplies = [];
    projectCards = [];
    options = [];
    agentforceAgentId = `0XxgL000000PR9tSAG`;
    recordicon = 'utility:muted';

    botAvatar = botAvatar;
    userAvatar = userAvatar;
    chatbotLogo = chatbotLogo;
    sessionId = null;

    /*@wire(getRecord, { recordId: '$recordId', fields: [URL_Field,Number_Field, Content_Field] })
     wiredRecord({ error, data }) {
         if (data) {
             this.scrap_number=data.fields.Webscrape_Number__c.value;
             this.url = data.fields.URL__c.value;
             console.log(this.url);
             console.log(this.scrap_number);
         } else if (error) {
             console.log('couldnt get record')
             if (!this.url)
                 this.addBotMessage('Sorry, I could not fetch the required URL.');
             console.error('Error loading record', error);
         }
     }*/

    /*@wire(getMetadataInfo)
    wiredMetadataInfo({ error, data }) {
        if (data) {
            try {
                //this.agentLoadingMessage = data.Agent_Loading_Message__c;
                //this.agentJoinedMessage = data.Agent_Joined_Message__c;
                //this.agentPlaceholder = data.Placeholder_For_Agent_Home_Screen__c;
                this.AgentName = data.Agent_Name__c;
                //this.HomeScreenAgentWidth = data.Home_Screen_Bot_Image_Width__c;
                //this.HomeScreenAgentHeight = data.Home_Screen_Bot_Image_Height__c;
               // this.HomeScreenBitImageStyle();
                //this.isLoading = false;
            } catch (e) {
                this.isLoading = false;
                console.error('Error parsing Metadata Info:', e.message);

            }
        } else if (error) {
            this.isLoading = false;
            console.error('Error fetching Metadata Info:', error);
        }
    }*/

    connectedCallback() {
        this.initChat();
    }


    async initChat() {
        //this.isLoading = true;
        if (!this.agentforceAgentId) {
            this.addBotMessage('Agent ID is missing. Cannot start chat.');
            return;
        }

        try {
            const welcomeMsgObj = await startChatSession({ AgentId: this.agentforceAgentId });
            this.sessionId = welcomeMsgObj.sessionId;
            this.addBotMessage('Hello! How can I help you today?', [
                { id: 1, text: 'Show all call agents' },
                { id: 2, text: 'Which Agent is performing better' },
                { id: 3, text: 'Show all calllogs agentwise' },
            ]);

        } catch (error) {
            this.addBotMessage('Failed to start agent', [
                { id: 1, text: 'Show all Call Agents' },
                { id: 2, text: 'Show dashboards' },
                { id: 3, text: 'School Location' },
            ]);
            //this.isLoading = false;
            console.error(error);
        }
    }

    /*@track currentlang = 'en-US';
    options=
         [
            { label: 'English', value: 'en-US' },
            { label: 'Bengali', value: 'bn-IN' },
            { label: 'Hindi', value: 'hi-IN' },
        ];*/

    handleChange(event) {
        this.currentlang = event.detail.value;
        console.log(this.currentlang);
    }

    toggleFullscreen() {
        this.isFullscreen = !this.isFullscreen;
        this.updateContainerStyle();
    }

    toggleChat() {
        this.isFullscreen = false;
        this.isOpen = !this.isOpen;
        this.updateContainerStyle();
    }

    // toggleChat() {
    //     this.isOpen = !this.isOpen;
    //     this.containerStyle = this.isOpen 
    //         ? 'display: block; bottom: 100px; right: 20px;' 
    //         : 'display: none; bottom: 100px; right: 20px;';
    // }

    updateContainerStyle() {
        try {
            if (this.isFullscreen) {
                this.chatMessagesStyle = 'height:72%';
                this.containerStyle = 'display: block; position: fixed; top: 0; left: 0; width: 100%; height: 100vh !important; z-index: 9999;bottom:0px;right:0px;';
            } else if (this.isOpen) {
                this.chatMessagesStyle = 'height:62%';
                this.containerStyle = 'display: block; position: fixed; bottom: 100px; right: 26px; width: 380px; height: 80vh; z-index: 9999;';
            } else {
                this.containerStyle = 'display: none;';
            }
        } catch (e) {
            console.log(e)
        }

    }

    // Update icon based on state
    get fullscreenIcon() {
        return this.isFullscreen ? 'utility:contract_alt' : 'utility:expand_alt';
    }

    /*handleInputChange(event) {
        this.newMessage = event.target.value;
    }*/

    handleKeyPress(event) {
        this.newMessage = event.target.value;
        console.log('inside key press', this.newMessage);
        if (event.key === 'Enter') {
            this.sendMessage();
        }
    }
    sendMessage() {

        const input = this.template.querySelector('lightning-input');
        const latestMessage = input?.value;
        if (latestMessage && latestMessage.trim()) {
            this.addUserMessage(latestMessage);
            this.getBotResponse();
            this.newMessage = '';
            if (input) input.value = '';
        }
    }



    /*recordMessage()
    {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        console.log('button clicked')
        const SpeechGrammarList = window.SpeechGrammarList || window.webkitSpeechGrammarList;
        if (!SpeechRecognition || !SpeechGrammarList) {
        console.error("Web Speech API is not supported in this browser");
        return;
        }
    
        this.recordicon="utility:unmuted";

        const recognition = new SpeechRecognition();
        //const speechRecognitionList = new SpeechGrammarList();
        //speechRecognitionList.addFromString(grammar, 1);
        //recognition.grammars = speechRecognitionList;
        recognition.continuous = false;
        recognition.lang = this.currentlang;
        //'en-US'-english
        //'bn-IN'-bengali
        //bn-BD
        //hi-IN-hindi
        recognition.interimResults = false;
        recognition.maxAlternatives = 1;

        recognition.onresult = (event) => {
            const message = event.results[0][0].transcript;
            //message = await this.translateText(message, this.currentlang.split('-')[0], 'en');
            console.log('you said',message);
            this.newMessage=message;
            recognition.stop();
           
        };

        recognition.onerror = (event) => {
        console.error("Speech recognition error:", event.error);
        this.recordicon = "utility:muted";
        recognition.stop();
    };

        recognition.onend = () => {
        this.recordicon = "utility:muted";
        this.sendMessage();
     };

        recognition.start();
    }*/




    addUserMessage(text) {
        this.messages.push({
            id: Date.now(),
            text: text,
            sender: 'user',
            senderAlt: 'You',
            avatar: this.userAvatar,
            containerClass: 'message-container user',
            bubbleClass: 'message-bubble user',
            timestamp: this.getCurrentTime()

        });
        console.log('user sent' + text);
        this.scrollToBottom();
    }




    addBotMessage(text, quickReplies = [], eliminateExisting = false) {
        this.messages.push({
            id: Date.now(),
            text: text,
            sender: 'bot',
            senderAlt: 'Assistant',
            avatar: this.botAvatar,
            containerClass: 'message-container bot',
            bubbleClass: 'message-bubble bot',
            timestamp: this.getCurrentTime()
        });
        console.log('bot respoded sent' + text);
        if (eliminateExisting) {
            this.quickReplies = [...quickReplies];
        } else {
            this.quickReplies = [...this.quickReplies, ...quickReplies];
        }
        this.showQuickReplies = this.quickReplies.length > 0;
        this.scrollToBottom();
    }

    async getBotResponse() {
        this.isBotTyping = true;
        console.log('inside bot function', this.newMessage);
        try {
            /*const history = this.messages.map(msg => ({
                className: msg.containerClass.includes('user') ? 'user-message' : 'bot-message',
                text: msg.text
            }));*/
            const response = await sendChatMessage({
                sessionId: this.sessionId,
                message: this.newMessage
            });
            console.log(response);

            let responseText = String(response).trim();
            responseText = responseText.replace(/(?!^)(\d+\.\s)/g, '</n>$1');
            responseText = responseText.replace(/\n/g, '<br/>');
            this.isBotTyping = false;
            this.addBotMessage(responseText)
            this.newMessage = '';

        } catch (error) {
            console.error('Error getting bot response:', error.message);
            this.isBotTyping = false;
            this.addBotMessage("Sorry, I encountered an error. Please try again.");
        }

    }

    handleQuickReply(event) {
        const replyText = event.target.label;
        this.newMessage = event.target.label
        this.addUserMessage(replyText);
        this.getBotResponse();
    }

    scrollToBottom() {
        setTimeout(() => {
            const container = this.template.querySelector('.chat-messages');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        }, 0);
    }

    getCurrentTime() {
        return new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
}